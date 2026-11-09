import '../../core/database/database_helper.dart';
import 'notification_repository.dart';

/// Partages de posts (comme Facebook) : Y partage le post de X →
/// le partage est enregistré (un seul par utilisateur et par post),
/// l'auteur est notifié, et le post partagé apparaît dans le profil du partageur.
class PartageRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> compter(int actualiteId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM partage_post WHERE actualite_id = ?',
      [actualiteId],
    );
    return (rows.first.values.first as int?) ?? 0;
  }

  Future<bool> aPartage(int actualiteId, int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.query(
      'partage_post',
      columns: ['id'],
      where: 'actualite_id = ? AND utilisateur_id = ?',
      whereArgs: [actualiteId, utilisateurId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Bascule le partage. Notifie l'auteur du post.
  /// Renvoie l'état après l'action (true = partagé).
  Future<bool> basculer({
    required int actualiteId,
    required int utilisateurId,
    int? auteurId,
    String acteurNom = '',
  }) async {
    final db = await _db.database;
    final deja = await aPartage(actualiteId, utilisateurId);
    if (deja) {
      await db.delete(
        'partage_post',
        where: 'actualite_id = ? AND utilisateur_id = ?',
        whereArgs: [actualiteId, utilisateurId],
      );
      return false;
    }
    await db.insert('partage_post', {
      'actualite_id': actualiteId,
      'utilisateur_id': utilisateurId,
      'cree_le': DateTime.now().toUtc().toIso8601String(),
    });
    if (auteurId != null) {
      await NotificationRepository().notifier(
        destinataireId: auteurId,
        acteurId: utilisateurId,
        acteurNom: acteurNom,
        type: 'participation',
        actualiteId: actualiteId,
        texte: '$acteurNom a partagé ton post',
      );
    }
    return true;
  }

  /// Posts partagés par [utilisateurId] (affichés dans son profil).
  Future<List<int>> idsPartages(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.query('partage_post',
        columns: ['actualite_id'],
        where: 'utilisateur_id = ?',
        whereArgs: [utilisateurId],
        orderBy: 'cree_le DESC');
    return [for (final r in rows) r['actualite_id'] as int];
  }
}
