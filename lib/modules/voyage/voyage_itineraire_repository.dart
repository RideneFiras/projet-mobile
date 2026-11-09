import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import 'models/itineraire.dart';

/// Sauvegarde locale de l'itinéraire d'un voyage (un seul par voyage).
class VoyageItineraireRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<(Confort, Itineraire)?> charger(int voyageId) async {
    final db = await _db.database;
    final rows = await db.query('voyage_itineraire',
        where: 'voyage_id = ?', whereArgs: [voyageId], limit: 1);
    if (rows.isEmpty) return null;
    try {
      return (
      Confort.depuis(rows.first['confort'] as String),
      Itineraire.depuisJson(jsonDecode(rows.first['contenu'] as String)),
      );
    } catch (_) {
      return null; // contenu illisible : on repart de zéro
    }
  }

  /// Remplace l'itinéraire existant (voyage_id est UNIQUE).
  Future<void> sauvegarder(int voyageId, Confort confort, Itineraire it) async {
    final db = await _db.database;
    await db.insert(
      'voyage_itineraire',
      {
        'voyage_id': voyageId,
        'confort': confort.valeur,
        'contenu': jsonEncode(it.toJson()),
        'cree_le': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
