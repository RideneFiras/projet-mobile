import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import 'models/offre_vol.dart';
import 'models/voyage.dart';
import 'models/voyage_vol.dart';

/// Catalogue des vols + création d'un voyage à partir d'une offre.
class VoyageVolRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// (ville, pays, latitude, longitude, durée en minutes depuis Tunis, prix éco en DT).
  /// Durées et prix : valeurs indicatives de démonstration.
  static const _catalogue = <(String, String, double, double, int, double)>[
    ('Rome', 'Italie', 41.9028, 12.4964, 90, 650),
    ('Paris', 'France', 48.8566, 2.3522, 165, 850),
    ('Milan', 'Italie', 45.4642, 9.1900, 130, 700),
    ('Istanbul', 'Turquie', 41.0082, 28.9784, 190, 900),
    ('Madrid', 'Espagne', 40.4168, -3.7038, 150, 780),
    ('Barcelone', 'Espagne', 41.3874, 2.1686, 125, 720),
    ('Berlin', 'Allemagne', 52.5200, 13.4050, 200, 950),
    ('Londres', 'Royaume-Uni', 51.5074, -0.1278, 210, 1050),
    ('Le Caire', 'Égypte', 30.0444, 31.2357, 180, 800),
    ('Dubaï', 'Émirats arabes unis', 25.2048, 55.2708, 360, 1900),
  ];

  /// Trois départs par ville : (jours à partir d'aujourd'hui, nuits sur place, facteur de prix).
  static const _departs = <(int, int, double)>[
    (12, 5, 1.0),
    (26, 7, 1.1),
    (45, 4, 0.95),
  ];

  /// Remplit le catalogue la première fois (table vide). On le fait ici car
  /// DatabaseHelper.onCreate ne s'exécute qu'à la toute première création de la base.
  Future<void> _assurerCatalogue(Database db) async {
    final n = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM offre_vol')) ??
        0;
    if (n > 0) return;
    final now = DateTime.now();
    final batch = db.batch();
    for (final (ville, pays, lat, lng, minutes, prix) in _catalogue) {
      for (final (jours, nuits, facteur) in _departs) {
        final depart = DateTime(now.year, now.month, now.day + jours);
        final retour = DateTime(now.year, now.month, now.day + jours + nuits);
        batch.insert(
          'offre_vol',
          OffreVol(
            ville: ville,
            pays: pays,
            latitude: lat,
            longitude: lng,
            dureeMinutes: minutes,
            dateDepart: depart,
            dateRetour: retour,
            prixBase: (prix * facteur).roundToDouble(),
          ).toMap(),
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Toutes les offres, par ville puis par date de départ.
  Future<List<OffreVol>> offres() async {
    final db = await _db.database;
    await _assurerCatalogue(db);
    final rows = await db.query('offre_vol', orderBy: 'ville, date_depart');
    return rows.map(OffreVol.fromMap).toList();
  }

  /// Une offre par ville (la moins chère) : sert aux épingles de la carte.
  Future<List<OffreVol>> destinations() async {
    final parVille = <String, OffreVol>{};
    for (final o in await offres()) {
      final deja = parVille[o.ville];
      if (deja == null || o.prixBase < deja.prixBase) parVille[o.ville] = o;
    }
    return parVille.values.toList();
  }

  /// Crée le voyage ET son vol en une seule transaction (tout ou rien).
  /// Règles appliquées ici : statut = planifié, budget = prix du billet calculé.
  Future<int> creerVoyageAvecVol({
    required String titre,
    required int utilisateurId,
    required OffreVol offre,
    required ClasseVol classe,
  }) async {
    final db = await _db.database;
    final prix = offre.prixPour(classe);
    final voyage = Voyage(
      titre: titre,
      destination: offre.ville,
      dateDebut: offre.dateDepart,
      dateFin: offre.dateRetour,
      budget: prix,
      statut: StatutVoyage.planifie,
      utilisateurId: utilisateurId,
    );
    return db.transaction((txn) async {
      final voyageId = await txn.insert('voyage', voyage.toMap());
      await txn.insert(
        'voyage_vol',
        VoyageVol(
            voyageId: voyageId,
            offreId: offre.id!,
            classe: classe,
            prix: prix)
            .toMap(),
      );
      return voyageId;
    });
  }

  /// Le vol d'un voyage, ou null (voyages créés avant cette fonctionnalité).
  Future<(VoyageVol, OffreVol)?> volDuVoyage(int voyageId) async {
    final db = await _db.database;
    final liens = await db.query('voyage_vol',
        where: 'voyage_id = ?', whereArgs: [voyageId], limit: 1);
    if (liens.isEmpty) return null;
    final lien = VoyageVol.fromMap(liens.first);
    final offres = await db.query('offre_vol',
        where: 'id = ?', whereArgs: [lien.offreId], limit: 1);
    if (offres.isEmpty) return null;
    return (lien, OffreVol.fromMap(offres.first));
  }
}
