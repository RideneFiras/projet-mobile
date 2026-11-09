import '../../core/database/database_helper.dart';
import 'notification_repository.dart';

/// Participations aux posts annonces (événements du fil).
/// Un utilisateur ne peut participer qu'une seule fois par annonce ;
/// re-toucher le bouton retire sa participation.
class ParticipationRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> compter(int actualiteId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM participation_actualite WHERE actualite_id = ?',
      [actualiteId],
    );
    return (rows.first.values.first as int?) ?? 0;
  }

  Future<bool> participe(int actualiteId, int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.query(
      'participation_actualite',
      columns: ['id'],
      where: 'actualite_id = ? AND utilisateur_id = ?',
      whereArgs: [actualiteId, utilisateurId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Bascule la participation. Renvoie l'état après l'action.
  /// Notifie l'auteur de l'annonce quand quelqu'un participe.
  Future<bool> basculer({
    required int actualiteId,
    required int utilisateurId,
    int? auteurId,
    String acteurNom = '',
  }) async {
    final db = await _db.database;
    final deja = await participe(actualiteId, utilisateurId);
    if (deja) {
      await db.delete(
        'participation_actualite',
        where: 'actualite_id = ? AND utilisateur_id = ?',
        whereArgs: [actualiteId, utilisateurId],
      );
      return false;
    }
    await db.insert('participation_actualite', {
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
        texte: '$acteurNom participe à ton annonce',
      );
    }
    return true;
  }
}
