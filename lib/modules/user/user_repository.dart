import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/password_hasher.dart';
import 'actualite.dart';
import 'role.dart';
import 'utilisateur.dart';

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

  Future<String?> connecter(String email, String motDePasse) async {
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
      return 'E-mail ou mot de passe incorrect';
    }
    await SessionService.instance.ouvrir(rows.first['id'] as int);
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
