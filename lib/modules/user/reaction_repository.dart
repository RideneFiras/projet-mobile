import '../../core/database/database_helper.dart';

/// Types de réactions (comme SyrWriteHub) : un seul choix par utilisateur
/// et par post ; en re-cliquant sur la même réaction, on la retire ;
/// en cliquant une autre, on la change.
class ReactionTypes {
  ReactionTypes._();

  static const like = 'like';
  static const love = 'love';
  static const wow = 'wow';
  static const haha = 'haha';
  static const sad = 'sad';
  static const angry = 'angry';

  static const values = [like, love, wow, haha, sad, angry];

  static const emojis = {
    like: '👍',
    love: '❤️',
    wow: '😮',
    haha: '😂',
    sad: '😢',
    angry: '😡',
  };

  static const labels = {
    like: "J'aime",
    love: "J'adore",
    wow: 'Wouah',
    haha: 'Haha',
    sad: 'Triste',
    angry: 'Fâché',
  };

  static String emojiDe(String type) => emojis[type] ?? emojis[like]!;
  static String labelDe(String type) => labels[type] ?? labels[like]!;
}

/// Réactions du fil d'actualité (système de rating type Facebook).
class ReactionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> compter(int actualiteId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM reaction_actualite WHERE actualite_id = ?',
      [actualiteId],
    );
    return (rows.first.values.first as int?) ?? 0;
  }

  /// Nombre par type de réaction (pour les icônes sous le post).
  Future<Map<String, int>> comptesParType(int actualiteId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT type, COUNT(*) AS n FROM reaction_actualite WHERE actualite_id = ? GROUP BY type',
      [actualiteId],
    );
    return {
      for (final r in rows) r['type'] as String: r['n'] as int,
    };
  }

  /// Type de réaction de [utilisateurId] sur ce post, ou null.
  Future<String?> maReaction(int actualiteId, int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.query(
      'reaction_actualite',
      columns: ['type'],
      where: 'actualite_id = ? AND utilisateur_id = ?',
      whereArgs: [actualiteId, utilisateurId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['type'] as String;
  }

  Future<bool> aReagi(int actualiteId, int utilisateurId) async =>
      await maReaction(actualiteId, utilisateurId) != null;

  /// Choisit une réaction :
  /// - même type que l'actuelle → la retire ;
  /// - autre type → la remplace ;
  /// - aucune → l'ajoute.
  /// Renvoie le type après l'action (null = retirée).
  Future<String?> choisir(int actualiteId, int utilisateurId, String type) async {
    final db = await _db.database;
    final actuelle = await maReaction(actualiteId, utilisateurId);
    if (actuelle == type) {
      await db.delete(
        'reaction_actualite',
        where: 'actualite_id = ? AND utilisateur_id = ?',
        whereArgs: [actualiteId, utilisateurId],
      );
      return null;
    }
    if (actuelle != null) {
      await db.update(
        'reaction_actualite',
        {'type': type},
        where: 'actualite_id = ? AND utilisateur_id = ?',
        whereArgs: [actualiteId, utilisateurId],
      );
      return type;
    }
    await db.insert('reaction_actualite', {
      'actualite_id': actualiteId,
      'utilisateur_id': utilisateurId,
      'type': type,
      'cree_le': DateTime.now().toUtc().toIso8601String(),
    });
    return type;
  }

  /// Bascule le J'aime (compatibilité, utilisé par les anciens écrans).
  Future<bool> basculer(int actualiteId, int utilisateurId) async =>
      await choisir(actualiteId, utilisateurId, ReactionTypes.like) != null;
}
