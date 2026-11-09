import '../../core/database/database_helper.dart';
import '../../core/utils/dates.dart';
import 'models/location_vehicule.dart';
import 'models/vehicule.dart';

/// Accès SQLite du module location (tables vehicule et location_vehicule).
class LocationRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ------------------------------------------------------------------
  // Véhicules (CRUD)
  // ------------------------------------------------------------------

  Future<List<Vehicule>> vehicules() async {
    final db = await _db.database;
    final rows = await db.query('vehicule',
        orderBy: 'marque COLLATE NOCASE, modele COLLATE NOCASE');
    return rows.map(Vehicule.fromMap).toList();
  }

  Future<int> creerVehicule(Vehicule v) async {
    final db = await _db.database;
    return db.insert('vehicule', v.toMap());
  }

  Future<void> modifierVehicule(Vehicule v) async {
    final db = await _db.database;
    await db.update('vehicule', v.toMap(), where: 'id = ?', whereArgs: [v.id]);
  }

  /// Les locations de ce véhicule sont supprimées avec lui (ON DELETE CASCADE).
  Future<void> supprimerVehicule(int id) async {
    final db = await _db.database;
    await db.delete('vehicule', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Locations (CRUD)
  // ------------------------------------------------------------------

  static const String _select = '''
    SELECT l.*, v.marque || ' ' || v.modele AS nom_vehicule, vo.titre AS titre_voyage
    FROM location_vehicule l
    JOIN vehicule v ON v.id = l.vehicule_id
    LEFT JOIN voyage vo ON vo.id = l.voyage_id
  ''';

  /// Locations rattachées aux voyages de l'utilisateur.
  Future<List<LocationVehicule>> locationsDe(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_select WHERE vo.utilisateur_id = ? ORDER BY l.date_debut, l.id',
        [utilisateurId]);
    return rows.map(LocationVehicule.fromMap).toList();
  }

  /// Enregistre (ajout ou modification) après contrôle, dans une transaction :
  /// véhicule disponible, pas de chevauchement, prix recalculé depuis le tarif.
  /// Renvoie un message d'erreur, ou null si tout est correct.
  Future<String?> enregistrer(LocationVehicule l) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final vehicule = await txn.query('vehicule',
          columns: ['prix_par_jour', 'disponible'],
          where: 'id = ?',
          whereArgs: [l.vehiculeId],
          limit: 1);
      if (vehicule.isEmpty) return 'Véhicule introuvable';
      if ((vehicule.first['disponible'] as int) != 1) {
        return 'Ce véhicule est actuellement indisponible';
      }

      // Chevauchement inclusif : deux locations partageant un jour sont en conflit.
      final occupe = await txn.query('location_vehicule',
          columns: ['id'],
          where: 'vehicule_id = ? AND date_debut <= ? AND date_fin >= ? AND id <> ?',
          whereArgs: [
            l.vehiculeId,
            dateIso(l.dateFin),
            dateIso(l.dateDebut),
            l.id ?? -1,
          ],
          limit: 1);
      if (occupe.isNotEmpty) {
        return 'Ce véhicule est déjà réservé sur une partie de ces dates';
      }

      final prixJour = (vehicule.first['prix_par_jour'] as num).toDouble();
      final valeurs = {...l.toMap(), 'prix_total': prixJour * l.jours};
      if (l.id == null) {
        await txn.insert('location_vehicule', valeurs);
      } else {
        await txn.update('location_vehicule', valeurs,
            where: 'id = ?', whereArgs: [l.id]);
      }
      return null;
    });
  }

  Future<void> supprimerLocation(int id) async {
    final db = await _db.database;
    await db.delete('location_vehicule', where: 'id = ?', whereArgs: [id]);
  }
}
