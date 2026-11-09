import '../../core/database/database_helper.dart';
import 'actualite.dart';
import 'role.dart';
import 'utilisateur.dart';

/// Opérations réservées à l'administrateur : publier, modifier et supprimer les
/// actualités ; lister et supprimer des comptes (jamais le sien ni un autre admin).
class AdminRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  String get _maintenant => DateTime.now().toUtc().toIso8601String();

  // ------------------------------------------------------------------
  // Actualités (CRUD)
  // ------------------------------------------------------------------

  Future<List<Actualite>> actualites() async {
    final db = await _db.database;
    final rows = await db.query('actualite',
        orderBy: 'date_publication DESC, id DESC');
    return rows.map(Actualite.fromMap).toList();
  }

  Future<void> publier({
    required String titre,
    required String contenu,
    required int auteurId,
  }) async {
    final db = await _db.database;
    await db.insert('actualite', {
      'titre': titre.trim(),
      'contenu': contenu.trim(),
      'date_publication': _maintenant,
      'auteur_id': auteurId,
    });
  }

  Future<void> modifierActualite(
    int id, {
    required String titre,
    required String contenu,
  }) async {
    final db = await _db.database;
    await db.update(
      'actualite',
      {'titre': titre.trim(), 'contenu': contenu.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> supprimerActualite(int id) async {
    final db = await _db.database;
    await db.delete('actualite', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Utilisateurs (lecture et suppression)
  // ------------------------------------------------------------------

  Future<List<Utilisateur>> utilisateurs() async {
    final db = await _db.database;
    final rows = await db.query('utilisateur',
        orderBy: 'role, nom COLLATE NOCASE, prenom COLLATE NOCASE');
    return rows.map(Utilisateur.fromMap).toList();
  }

  /// Supprime le compte et, par cascade, ses voyages, commandes et avis.
  /// Renvoie un message d'erreur, ou null si la suppression a eu lieu.
  Future<String?> supprimerUtilisateur(int id, int adminId) async {
    if (id == adminId) return 'Vous ne pouvez pas supprimer votre propre compte';
    final db = await _db.database;
    final rows = await db.query('utilisateur',
        columns: ['role'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return 'Utilisateur introuvable';
    if (rows.first['role'] == Role.admin.valeur) {
      return 'Un administrateur ne peut pas être supprimé ici';
    }
    await db.delete('utilisateur', where: 'id = ?', whereArgs: [id]);
    return null;
  }
}
