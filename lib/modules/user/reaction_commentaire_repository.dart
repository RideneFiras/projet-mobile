import '../../core/database/database_helper.dart';
import 'reaction_repository.dart';

/// Réactions emoji sur les commentaires (même système que les posts).
class ReactionCommentaireRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<String?> maReaction(int commentaireId, int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.query(
      'reaction_commentaire',
      columns: ['type'],
      where: 'commentaire_id = ? AND utilisateur_id = ?',
      whereArgs: [commentaireId, utilisateurId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['type'] as String;
  }

  Future<int> compter(int commentaireId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM reaction_commentaire WHERE commentaire_id = ?',
      [commentaireId],
    );
    return (rows.first.values.first as int?) ?? 0;
  }

  /// Même type = retire, autre = remplace, aucune = ajoute.
  /// Seulement l'auteur gérera ensuite modifier/supprimer.
  Future<String?> choisir(int commentaireId, int utilisateurId, String type) async {
    final db = await _db.database;
    final actuelle = await maReaction(commentaireId, utilisateurId);
    if (actuelle == type) {
      await db.delete(
        'reaction_commentaire',
        where: 'commentaire_id = ? AND utilisateur_id = ?',
        whereArgs: [commentaireId, utilisateurId],
      );
      return null;
    }
    if (actuelle != null) {
      await db.update(
        'reaction_commentaire',
        {'type': type},
        where: 'commentaire_id = ? AND utilisateur_id = ?',
        whereArgs: [commentaireId, utilisateurId],
      );
      return type;
    }
    await db.insert('reaction_commentaire', {
      'commentaire_id': commentaireId,
      'utilisateur_id': utilisateurId,
      'type': type,
      'cree_le': DateTime.now().toUtc().toIso8601String(),
    });
    return type;
  }
}
