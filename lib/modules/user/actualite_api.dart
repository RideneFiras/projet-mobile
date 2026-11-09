import '../../core/services/api_service.dart';
import 'actualite.dart';
import 'actualite_fil.dart';
import 'commentaire.dart';
import 'commentaire_repository.dart';
import 'role.dart';
import 'user_repository.dart';

/// Origine d'un brouillon : affichée à l'administrateur pour savoir qui a répondu.
enum SourceBrouillon { serveur, local }

/// Brouillon d'actualité généré (IA ou repli local), à valider avant publication.
class BrouillonActualite {
  final String titre;
  final String contenu;
  final SourceBrouillon source;

  const BrouillonActualite({
    required this.titre,
    required this.contenu,
    required this.source,
  });
}

/// Client de l'API REST des actualités (serveur applicatif, `server/`).
///
/// Règles, comme pour l'assistant IA du module transporteur :
///  - l'appel au modèle passe toujours par le serveur, jamais depuis l'app ;
///  - sans serveur (ou en erreur), on bascule sur la version locale SQLite ;
///  - le rôle est transmis à l'API dans le corps ou en paramètre
///    (authentification de développement, voir server/actualite_api.js).
class ActualiteApi {
  ActualiteApi._();

  static const String _base = '/actualites';
  static const String _brouillon = '/actualites/brouillon';

  // ------------------------------------------------------------------
  // Lecture : serveur, sinon base locale
  // ------------------------------------------------------------------

  static Future<List<Actualite>> lister({
    Role? role,
    CategorieActualite? categorie,
    String recherche = '',
    int page = 1,
    int limite = 20,
  }) async {
    final requete = <String, String>{
      if (role != null) 'role': role.valeur,
      if (categorie != null) 'categorie': categorie.valeur,
      if (recherche.trim().isNotEmpty) 'q': recherche.trim(),
      'page': '$page',
      'limite': '$limite',
    };
    final chaine = requete.entries.map((e) => '${e.key}=${e.value}').join('&');
    try {
      final rep = await ApiService.instance.get('$_base?$chaine');
      if (rep is Map && rep['resultats'] is List) {
        return [
          for (final e in rep['resultats'] as List)
            if (e is Map) Actualite.fromMap(e.cast<String, dynamic>()),
        ];
      }
    } on Exception catch (_) {
      // Serveur indisponible : on bascule sur la base locale.
    }
    final locales = await UserRepository().actualites(role: role);
    return FilActualites.filtrer(
      locales,
      role: role,
      recherche: recherche,
      categorie: categorie,
    );
  }

  // ------------------------------------------------------------------
  // Écritures : serveur seul (message d'erreur, ou null si enregistré).
  // La base locale reste la source de vérité sur l'appareil.
  // ------------------------------------------------------------------

  static Future<String?> publier({
    required String titre,
    required String contenu,
    required AudienceActualite audience,
    required CategorieActualite categorie,
    required Role role,
    String? photoBase64,
  }) =>
      _ecrire('POST', _base, {
        'titre': titre,
        'contenu': contenu,
        'photo': photoBase64,
        'audience': audience.valeur,
        'categorie': categorie.valeur,
        'role': role.valeur,
      });

  static Future<String?> modifier({
    required int id,
    required String titre,
    required String contenu,
    required AudienceActualite audience,
    required CategorieActualite categorie,
    required Role role,
    String? photoBase64,
  }) =>
      _ecrire('PUT', '$_base/$id', {
        'titre': titre,
        'contenu': contenu,
        'photo': photoBase64,
        'audience': audience.valeur,
        'categorie': categorie.valeur,
        'role': role.valeur,
      });

  static Future<String?> supprimer({required int id, required Role role}) =>
      _ecrire('DELETE', '$_base/$id?role=${role.valeur}', null);

  static Future<String?> _ecrire(String methode, String route, Map<String, dynamic>? corps) async {
    try {
      switch (methode) {
        case 'POST':
          await ApiService.instance.post(route, corps ?? {});
        case 'PUT':
          await ApiService.instance.put(route, corps ?? {});
        case 'DELETE':
          await ApiService.instance.delete(route);
      }
      return null;
    } on ApiException catch (e) {
      return e.code == 403
          ? 'Réservé aux administrateurs'
          : e.code == 404
              ? 'Actualité introuvable sur le serveur'
              : 'Échec (${e.code}) : ${e.message}';
    } on Exception {
      return 'Serveur indisponible : enregistrement non effectué';
    }
  }

  // ------------------------------------------------------------------
  // Commentaires : serveur, sinon base locale (auteur seul, comme l'app)
  // ------------------------------------------------------------------

  static Future<List<CommentaireActualite>> commentaires(int actualiteId) async {
    try {
      final rep = await ApiService.instance.get('$_base/$actualiteId/commentaires');
      if (rep is List) {
        return [
          for (final e in rep)
            if (e is Map) CommentaireActualite.fromMap(e.cast<String, dynamic>()),
        ];
      }
    } on Exception catch (_) {
      // Repli local ci-dessous.
    }
    return CommentaireRepository().lister(actualiteId);
  }

  /// Ajoute un commentaire. Renvoie un message d'erreur, ou null si enregistré.
  static Future<String?> commenter({
    required int actualiteId,
    required int auteurId,
    required String auteurNom,
    required String contenu,
    required Role role,
  }) async {
    try {
      await ApiService.instance.post('$_base/$actualiteId/commentaires', {
        'role': role.valeur,
        'auteur_id': auteurId,
        'auteur_nom': auteurNom,
        'contenu': contenu,
        'categorie': 'general',
      });
      return null;
    } on Exception {
      await CommentaireRepository().ajouter(
        actualiteId: actualiteId,
        auteurId: auteurId,
        auteurNom: auteurNom,
        contenu: contenu,
      );
      return null; // enregistré en local
    }
  }

  // ------------------------------------------------------------------
  // IA : brouillon à valider, sinon gabarit local
  // ------------------------------------------------------------------

  static Future<BrouillonActualite> brouillon({
    required String theme,
    AudienceActualite audience = AudienceActualite.tous,
    CategorieActualite categorie = CategorieActualite.general,
  }) async {
    try {
      final rep = await ApiService.instance.post(_brouillon, {
        'theme': theme.trim(),
        'audience': audience.valeur,
        'categorie': categorie.valeur,
      });
      if (rep is Map && rep['titre'] is String && rep['contenu'] is String) {
        final titre = (rep['titre'] as String).trim();
        final contenu = (rep['contenu'] as String).trim();
        if (FilActualites.valider(titre, contenu) == null) {
          return BrouillonActualite(
            titre: titre,
            contenu: contenu,
            source: SourceBrouillon.serveur,
          );
        }
      }
    } on Exception catch (_) {
      // Serveur indisponible ou réponse inexploitable : repli local ci-dessous.
    }
    return brouillonLocal(theme: theme, categorie: categorie);
  }

  /// Gabarit local, sans réseau : un brouillon neutre à partir du thème.
  /// Il ne contient aucun prix, aucune date et aucun détail inventé.
  static BrouillonActualite brouillonLocal({
    required String theme,
    CategorieActualite categorie = CategorieActualite.general,
  }) {
    final t = theme.trim();
    return BrouillonActualite(
      titre: '${t[0].toUpperCase()}${t.substring(1)}',
      contenu:
          'Travel Platform vous informe : $t. Retrouvez toutes les informations '
          'dans l’onglet Actualités. ${categorie.libelle} — ${DateTime.now().year}.',
      source: SourceBrouillon.local,
    );
  }
}
