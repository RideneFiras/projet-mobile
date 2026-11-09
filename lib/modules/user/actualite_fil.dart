import '../../core/utils/dates.dart';
import 'actualite.dart';
import 'commentaire.dart';
import 'role.dart';

/// Logique pure du fil d'actualité : fil commun à tous les utilisateurs,
/// recherche, validation et droits de modification.
/// Tout utilisateur connecté peut publier ou commenter ; chacun modifie ou
/// supprime UNIQUEMENT ses propres publications et ses propres commentaires
/// (comme sous un post Facebook : on ne touche jamais à ceux des autres).
/// Aucun accès à la base (testable seule, comme `transport_format.dart`).
class FilActualites {
  FilActualites._();

  static const titreMin = 3;
  static const titreMax = 120;
  static const contenuMin = 10;
  static const contenuMax = 2000;

  /// Message d'erreur à afficher, ou null si la saisie est valide.
  /// [sondage] = true : la question remplace le texte du post, le contenu
  /// est alors facultatif (seul le maximum s'applique).
  static String? valider(String titre, String contenu, {bool sondage = false}) {
    final t = titre.trim();
    final c = contenu.trim();
    if (t.length < titreMin) return 'Titre trop court ($titreMin caractères minimum)';
    if (t.length > titreMax) return 'Titre trop long ($titreMax caractères maximum)';
    if (!sondage && c.length < contenuMin) return 'Contenu trop court ($contenuMin caractères minimum)';
    if (c.length > contenuMax) return 'Contenu trop long ($contenuMax caractères maximum)';
    return null;
  }

  /// Fil commun : toutes les actualités sont visibles par tous les
  /// utilisateurs connectés (pas de filtre par rôle).
  static bool estVisiblePour(Actualite a, Role? role) => true;

  /// Seul l'auteur peut modifier ou supprimer son actualité.
  /// (La modération de tous les contenus reste possible depuis l'écran
  /// de gestion réservé à l'administrateur, hors du fil.)
  static bool peutModifier(Actualite a, {required int? utilisateurId, Role? role}) {
    return utilisateurId != null && a.auteurId == utilisateurId;
  }

  /// Seul l'auteur du commentaire peut le modifier ou le supprimer.
  static bool peutModifierCommentaire(
    CommentaireActualite commentaire, {
    required int? utilisateurId,
  }) {
    return utilisateurId != null && commentaire.auteurId == utilisateurId;
  }

  /// Fil principal : recherche (titre + contenu, sans accents ni casse),
  /// catégorie, puis tri du plus récent au plus ancien.
  /// [categorie] null = toutes les catégories.
  static List<Actualite> filtrer(
    List<Actualite> liste, {
    Role? role,
    String recherche = '',
    CategorieActualite? categorie,
  }) {
    final q = _normaliser(recherche.trim());
    final resultat = liste.where((a) {
      if (categorie != null && a.categorie != categorie) return false;
      return q.isEmpty ||
          _normaliser(a.titre).contains(q) ||
          _normaliser(a.contenu).contains(q);
    }).toList();
    resultat.sort((x, y) => y.datePublication.compareTo(x.datePublication));
    return resultat;
  }

  /// Temps relatif (« à l'instant », « il y a 5 min »…), comme Facebook.
  static String tempsRelatif(DateTime date) {
    final d = DateTime.now().difference(date);
    if (d.inMinutes < 1) return "à l'instant";
    if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
    if (d.inHours < 24) return 'il y a ${d.inHours} h';
    if (d.inDays < 30) return 'il y a ${d.inDays} j';
    return dateCourte(date);
  }

  /// Pourcentage d'une option de sondage (0 si aucun vote).
  static double pourcentage(int votes, int total) =>
      total <= 0 ? 0 : votes * 100.0 / total;

  /// Aperçu d'une carte : texte tronqué sans couper un mot.
  static String extrait(String contenu, {int max = 140}) {
    final c = contenu.trim();
    if (c.length <= max) return c;
    final coupe = c.substring(0, max);
    final dernierEspace = coupe.lastIndexOf(' ');
    return '${dernierEspace > 0 ? coupe.substring(0, dernierEspace) : coupe}…';
  }

  static String _normaliser(String s) {
    const accents = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n', 'ÿ': 'y',
    };
    final minuscule = s.toLowerCase();
    return minuscule.split('').map((c) => accents[c] ?? c).join();
  }
}
