import '../../core/database/database_helper.dart';
import 'message_prive.dart';

/// Messenger du fil d'actualité : messages privés entre utilisateurs.
/// On entre en contact depuis un post (bouton « Message » sur le post
/// d'un autre), puis on discute comme sur Facebook.
class MessageRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Conversation avec un interlocuteur, du plus ancien au plus récent.
  Future<List<MessagePrive>> conversation(int moiId, int autreId) async {
    final db = await _db.database;
    final rows = await db.query(
      'message_prive',
      where:
          '(expediteur_id = ? AND destinataire_id = ?) OR (expediteur_id = ? AND destinataire_id = ?)',
      whereArgs: [moiId, autreId, autreId, moiId],
      orderBy: 'cree_le ASC, id ASC',
    );
    return rows.map(MessagePrive.fromMap).toList();
  }

  Future<void> envoyer({
    required int expediteurId,
    required int destinataireId,
    required String contenu,
    String type = 'texte',
  }) async {
    final db = await _db.database;
    await db.insert('message_prive', {
      'expediteur_id': expediteurId,
      'destinataire_id': destinataireId,
      'contenu': contenu.trim(),
      'type': type,
      'cree_le': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Conversations de [moiId], la plus récente d'abord.
  Future<List<Conversation>> conversations(int moiId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT m.*, u.prenom || ' ' || u.nom AS autre_nom
      FROM message_prive m
      JOIN utilisateur u ON u.id = CASE WHEN m.expediteur_id = ? THEN m.destinataire_id ELSE m.expediteur_id END
      WHERE m.expediteur_id = ? OR m.destinataire_id = ?
      ORDER BY m.cree_le DESC, m.id DESC
    ''', [moiId, moiId, moiId]);
    final vus = <int>{};
    final liste = <Conversation>[];
    for (final r in rows) {
      final autre = (r['expediteur_id'] == moiId) ? r['destinataire_id'] as int : r['expediteur_id'] as int;
      if (!vus.add(autre)) continue;
      liste.add(Conversation(
        autreId: autre,
        autreNom: r['autre_nom'] as String,
        dernierMessage: r['contenu'] as String,
        dernierDate: DateTime.parse(r['cree_le'] as String),
      ));
    }
    return liste;
  }
}
