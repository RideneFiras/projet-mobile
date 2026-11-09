import '../../core/database/database_helper.dart';
import 'historique.dart';

/// Historique des posts : chaque modification et chaque suppression
/// archive la version précédente (stockage conservé pour toujours).
class HistoriqueRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Archive une version d'un post (appelé avant modification/suppression).
  Future<void> archiver({
    required int actualiteId,
    required String titre,
    required String contenu,
    int? auteurId,
    required String action,
  }) async {
    final db = await _db.database;
    await db.insert('historique_post', {
      'actualite_id': actualiteId,
      'titre': titre,
      'contenu': contenu,
      'auteur_id': auteurId,
      'action': action,
      'cree_le': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Versions d'un post, de la plus récente à la plus ancienne.
  /// Seulement l'auteur (ou le post supprimé restant du même auteur).
  Future<List<VersionPost>> versions(int actualiteId, int auteurId) async {
    final db = await _db.database;
    final rows = await db.query(
      'historique_post',
      where: 'actualite_id = ? AND auteur_id = ?',
      whereArgs: [actualiteId, auteurId],
      orderBy: 'cree_le DESC, id DESC',
    );
    return rows.map(VersionPost.fromMap).toList();
  }

  /// Historique complet d'un auteur (posts existants et supprimés).
  Future<List<VersionPost>> tout(int auteurId) async {
    final db = await _db.database;
    final rows = await db.query(
      'historique_post',
      where: 'auteur_id = ?',
      whereArgs: [auteurId],
      orderBy: 'cree_le DESC, id DESC',
    );
    return rows.map(VersionPost.fromMap).toList();
  }
}
