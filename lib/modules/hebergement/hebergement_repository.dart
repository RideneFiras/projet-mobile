import '../../core/database/database_helper.dart';
import 'models/hebergement.dart';
import 'models/reservation_hebergement.dart';

/// Accès SQLite du module hébergement (tables hebergement et reservation_hebergement).
class HebergementRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ------------------------------------------------------------------
  // Établissements (CRUD)
  // ------------------------------------------------------------------

  Future<List<Hebergement>> hebergements() async {
    final db = await _db.database;
    final rows = await db.query('hebergement', orderBy: 'nom COLLATE NOCASE');
    return rows.map(Hebergement.fromMap).toList();
  }

  Future<int> creerHebergement(Hebergement h) async {
    final db = await _db.database;
    return db.insert('hebergement', h.toMap());
  }

  Future<void> modifierHebergement(Hebergement h) async {
    final db = await _db.database;
    await db.update('hebergement', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
  }

  /// Les séjours réservés dans cet établissement sont supprimés avec lui.
  Future<void> supprimerHebergement(int id) async {
    final db = await _db.database;
    await db.delete('hebergement', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Séjours (CRUD)
  // ------------------------------------------------------------------

  static const String _select = '''
    SELECT r.*, h.nom AS nom_hebergement, vo.titre AS titre_voyage
    FROM reservation_hebergement r
    JOIN hebergement h ON h.id = r.hebergement_id
    LEFT JOIN voyage vo ON vo.id = r.voyage_id
  ''';

  /// Séjours rattachés aux voyages de l'utilisateur.
  Future<List<ReservationHebergement>> sejoursDe(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_select WHERE vo.utilisateur_id = ? ORDER BY r.date_arrivee, r.id',
        [utilisateurId]);
    return rows.map(ReservationHebergement.fromMap).toList();
  }

  /// Enregistre un séjour : prix recalculé (prix par nuit x nuits).
  /// Renvoie un message d'erreur, ou null si tout est correct.
  Future<String?> enregistrerSejour(ReservationHebergement s) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final h = await txn.query('hebergement',
          columns: ['prix_par_nuit'],
          where: 'id = ?',
          whereArgs: [s.hebergementId],
          limit: 1);
      if (h.isEmpty) return 'Hébergement introuvable';
      final prixNuit = (h.first['prix_par_nuit'] as num).toDouble();

      final Map<String, Object?> valeurs = {
        ...s.toMap(),
        'prix_total': prixNuit * s.nuits,
      };
      if (s.id == null) {
        await txn.insert('reservation_hebergement', valeurs);
      } else {
        await txn.update('reservation_hebergement', valeurs,
            where: 'id = ?', whereArgs: [s.id]);
      }
      return null;
    });
  }

  Future<void> supprimerSejour(int id) async {
    final db = await _db.database;
    await db.delete('reservation_hebergement', where: 'id = ?', whereArgs: [id]);
  }
}
