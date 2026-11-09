import '../../core/database/database_helper.dart';
import 'sondage.dart';

/// Sondages du fil d'actualité (comme les sondages Facebook).
///
/// Règles : 2 à 4 options par post ; un seul vote par utilisateur et
/// par sondage (changer d'avis remplace le vote précédent).
class SondageRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<OptionSondage>> optionsPour(int actualiteId) async {
    final db = await _db.database;
    final rows = await db.query(
      'sondage_option',
      where: 'actualite_id = ?',
      whereArgs: [actualiteId],
      orderBy: 'ordre ASC, id ASC',
    );
    return rows.map(OptionSondage.fromMap).toList();
  }

  Future<bool> estSondage(int actualiteId) async =>
      (await optionsPour(actualiteId)).length >= 2;

  Future<void> creerOptions(int actualiteId, List<String> libelles) async {
    final db = await _db.database;
    for (var i = 0; i < libelles.length; i++) {
      await db.insert('sondage_option', {
        'actualite_id': actualiteId,
        'libelle': libelles[i].trim(),
        'ordre': i,
      });
    }
  }

  /// Enregistre (ou remplace) le vote de [utilisateurId] pour [optionId].
  Future<void> voter({
    required int actualiteId,
    required int optionId,
    required int utilisateurId,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'sondage_vote',
        where: 'actualite_id = ? AND utilisateur_id = ?',
        whereArgs: [actualiteId, utilisateurId],
      );
      await txn.insert('sondage_vote', {
        'actualite_id': actualiteId,
        'option_id': optionId,
        'utilisateur_id': utilisateurId,
        'cree_le': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  /// Résultats avec pourcentages ; [utilisateurId] marque son choix.
  Future<List<ResultatSondage>> resultats(int actualiteId, {int? utilisateurId}) async {
    final db = await _db.database;
    final options = await optionsPour(actualiteId);
    final comptes = <int, int>{};
    final rows = await db.rawQuery(
      'SELECT option_id, COUNT(*) AS n FROM sondage_vote WHERE actualite_id = ? GROUP BY option_id',
      [actualiteId],
    );
    for (final r in rows) {
      comptes[r['option_id'] as int] = r['n'] as int;
    }
    int? monChoix;
    if (utilisateurId != null) {
      final miens = await db.query(
        'sondage_vote',
        columns: ['option_id'],
        where: 'actualite_id = ? AND utilisateur_id = ?',
        whereArgs: [actualiteId, utilisateurId],
        limit: 1,
      );
      if (miens.isNotEmpty) monChoix = miens.first['option_id'] as int;
    }
    final total = comptes.values.fold<int>(0, (s, n) => s + n);
    return [
      for (final o in options)
        ResultatSondage(
          option: o,
          votes: comptes[o.id] ?? 0,
          pourcentage: total == 0 ? 0 : (comptes[o.id] ?? 0) * 100.0 / total,
          choisi: monChoix == o.id,
        ),
    ];
  }
}
