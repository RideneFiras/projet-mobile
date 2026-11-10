import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/password_hasher.dart';
import 'actualite.dart';
import 'role.dart';
import 'utilisateur.dart';
import 'visage/comparateur_visage.dart';

/// Résultat de l'étape 1 de la connexion (e-mail + mot de passe).
class ResultatConnexion {
  /// Message à afficher si les identifiants sont faux.
  final String? erreur;

  /// Identifiants corrects mais vérification faciale requise pour ce compte.
  final int? visageRequisPour;

  const ResultatConnexion({this.erreur, this.visageRequisPour});
}

/// Accès aux tables "utilisateur" et "actualite" + inscription / connexion.
/// Les méthodes d'authentification renvoient null si tout va bien,
/// sinon un message d'erreur à afficher.
class UserRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<String?> inscrire({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required String motDePasse,
    required Role role,
  }) async {
    if (role == Role.admin) return 'Rôle non autorisé';
    final db = await _db.database;
    final sel = PasswordHasher.genererSel();
    try {
      final id = await db.insert('utilisateur', {
        'nom': nom.trim(),
        'prenom': prenom.trim(),
        'email': email.trim().toLowerCase(),
        'telephone': telephone.trim(),
        'role': role.valeur,
        'mot_de_passe_hash': PasswordHasher.hacher(motDePasse, sel),
        'sel': sel,
        'cree_le': DateTime.now().toUtc().toIso8601String(),
      });
      await SessionService.instance.ouvrir(id);
      return null;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return 'Cet e-mail est déjà utilisé';
      return "Erreur lors de l'inscription";
    }
  }

  /// Connexion en deux étapes.
  /// Étape 1 : e-mail + mot de passe. Si la vérification faciale est activée,
  /// la session n'est PAS ouverte : le résultat contient [ResultatConnexion.visageRequisPour]
  /// et il faut appeler [connecterAvecVisage] (étape 2).
  Future<ResultatConnexion> connexion(String email, String motDePasse) async {
    final db = await _db.database;
    final rows = await db.query(
      'utilisateur',
      columns: ['id', 'mot_de_passe_hash', 'sel'],
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty ||
        !PasswordHasher.verifier(motDePasse, rows.first['sel'] as String,
            rows.first['mot_de_passe_hash'] as String)) {
      return const ResultatConnexion(erreur: 'E-mail ou mot de passe incorrect');
    }
    final id = rows.first['id'] as int;
    if (await visageActive(id)) {
      return ResultatConnexion(visageRequisPour: id);
    }
    await SessionService.instance.ouvrir(id);
    return const ResultatConnexion();
  }

  /// Connexion simple : null si la session est ouverte, sinon un message.
  /// Un compte protégé par la vérification faciale doit passer par [connexion].
  Future<String?> connecter(String email, String motDePasse) async {
    final r = await connexion(email, motDePasse);
    if (r.erreur != null) return r.erreur;
    if (r.visageRequisPour != null) return 'Vérification faciale requise';
    return null;
  }

  // ---------------- Vérification faciale (2FA) ----------------

  Future<bool> visageActive(int utilisateurId) async =>
      (await _descripteurVisage(utilisateurId)) != null;

  Future<List<double>?> _descripteurVisage(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.query('visage_utilisateur',
        columns: ['descripteur'],
        where: 'utilisateur_id = ?',
        whereArgs: [utilisateurId],
        limit: 1);
    if (rows.isEmpty) return null;
    return ComparateurVisage.decoder(rows.first['descripteur'] as String);
  }

  /// Enregistre (ou remplace) le visage de référence du compte.
  Future<String?> activerVisage(int utilisateurId, List<double> descripteur) async {
    if (!ComparateurVisage.estValide(descripteur)) return 'Visage invalide';
    final db = await _db.database;
    await db.insert(
      'visage_utilisateur',
      {
        'utilisateur_id': utilisateurId,
        'descripteur': ComparateurVisage.encoder(descripteur),
        'active_le': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return null;
  }

  Future<void> desactiverVisage(int utilisateurId) async {
    final db = await _db.database;
    await db.delete('visage_utilisateur',
        where: 'utilisateur_id = ?', whereArgs: [utilisateurId]);
  }

  /// Étape 2 de la connexion : compare le visage capturé à la référence
  /// et ouvre la session s'il correspond. Renvoie null si tout va bien.
  Future<String?> connecterAvecVisage(
      int utilisateurId, List<double> capture) async {
    final reference = await _descripteurVisage(utilisateurId);
    if (reference == null) return 'Aucun visage enregistré pour ce compte';
    if (!ComparateurVisage.estValide(capture) ||
        !ComparateurVisage.correspond(reference, capture)) {
      return 'Visage non reconnu';
    }
    await SessionService.instance.ouvrir(utilisateurId);
    return null;
  }

  Future<void> deconnecter() => SessionService.instance.fermer();

  /// Utilisateur connecté (relu en base), ou null.
  Future<Utilisateur?> utilisateurConnecte() async {
    final id = await SessionService.instance.utilisateurId();
    if (id == null) return null;
    final db = await _db.database;
    final rows =
        await db.query('utilisateur', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      await SessionService.instance.fermer();
      return null;
    }
    return Utilisateur.fromMap(rows.first);
  }

  /// L'e-mail et le rôle ne sont pas modifiables.
  Future<void> mettreAJourProfil(Utilisateur u) async {
    final db = await _db.database;
    await db.update(
      'utilisateur',
      {'nom': u.nom.trim(), 'prenom': u.prenom.trim(), 'telephone': u.telephone.trim()},
      where: 'id = ?',
      whereArgs: [u.id],
    );
  }

  Future<List<Actualite>> actualites({int? limite}) async {
    final db = await _db.database;
    final rows = await db.query('actualite',
        orderBy: 'date_publication DESC, id DESC', limit: limite);
    return rows.map(Actualite.fromMap).toList();
  }
}
