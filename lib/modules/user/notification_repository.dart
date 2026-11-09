import '../../core/database/database_helper.dart';
import 'notification.dart';

/// Notifications du fil : créées automatiquement quand quelqu'un réagit
/// au post d'un autre (commentaire, J'aime, vote, participation).
/// Jamais à soi-même.
class NotificationRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> notifier({
    required int destinataireId,
    required int acteurId,
    required String acteurNom,
    required String type,
    int? actualiteId,
    required String texte,
  }) async {
    if (destinataireId == acteurId) return; // pas de notification pour soi-même
    final db = await _db.database;
    await db.insert('notification_fil', {
      'destinataire_id': destinataireId,
      'acteur_id': acteurId,
      'acteur_nom': acteurNom,
      'type': type,
      'actualite_id': actualiteId,
      'texte': texte,
      'lue': 0,
      'cree_le': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<NotificationFil>> lister(int destinataireId) async {
    final db = await _db.database;
    final rows = await db.query(
      'notification_fil',
      where: 'destinataire_id = ?',
      whereArgs: [destinataireId],
      orderBy: 'cree_le DESC, id DESC',
    );
    return rows.map(NotificationFil.fromMap).toList();
  }

  Future<int> nonLues(int destinataireId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM notification_fil WHERE destinataire_id = ? AND lue = 0',
      [destinataireId],
    );
    return (rows.first.values.first as int?) ?? 0;
  }

  Future<void> toutMarquerLu(int destinataireId) async {
    final db = await _db.database;
    await db.update(
      'notification_fil',
      {'lue': 1},
      where: 'destinataire_id = ?',
      whereArgs: [destinataireId],
    );
  }
}
