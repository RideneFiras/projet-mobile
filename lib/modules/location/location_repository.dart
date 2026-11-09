import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/geo.dart';
import 'models/blocage_vehicule.dart';
import 'models/filtres_vehicule.dart';
import 'models/location_vehicule.dart';
import 'models/statistiques_location.dart';
import 'models/vehicule.dart';

/// Accès SQLite du module location (tables vehicule et location_vehicule).
class LocationRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ------------------------------------------------------------------
  // Véhicules
  // ------------------------------------------------------------------

  /// Colonnes calculées : loué aujourd'hui, note moyenne, nombre d'avis (forum),
  /// nombre de locations non annulées (popularité).
  static const String _selectVehicule = '''
    SELECT v.*,
      EXISTS (SELECT 1 FROM location_vehicule l
              WHERE l.vehicule_id = v.id AND l.statut <> 'annulee'
                AND l.date_debut <= ? AND IFNULL(l.date_retour_reelle, l.date_fin) >= ?)
        AS en_location,
      (SELECT ROUND(AVG(a.note), 1) FROM avis a
        WHERE a.cible_type = 'location' AND a.cible_id = v.id) AS note_moyenne,
      (SELECT COUNT(*) FROM avis a
        WHERE a.cible_type = 'location' AND a.cible_id = v.id) AS nb_avis,
      (SELECT COUNT(*) FROM location_vehicule l2
        WHERE l2.vehicule_id = v.id AND l2.statut <> 'annulee') AS nb_locations
    FROM vehicule v
  ''';

  /// Liste filtrée et triée. [reservablesSeulement] = statut « disponible » uniquement.
  /// [filtres] regroupe tous les critères ; [type], [recherche] et [prixMax] restent
  /// disponibles en raccourci (ils priment sur [filtres]).
  /// La recherche porte sur marque, modèle, immatriculation, couleur et adresse.
  Future<List<Vehicule>> vehicules({
    TypeVehicule? type,
    bool reservablesSeulement = false,
    String? recherche,
    double? prixMax,
    FiltresVehicule? filtres,
  }) async {
    final f = filtres ?? const FiltresVehicule();
    final db = await _db.database;
    final auj = dateIso(DateTime.now());
    final conditions = <String>[];
    final args = <Object?>[auj, auj];
    final typeChoisi = type ?? f.type;
    if (typeChoisi != null) {
      conditions.add('v.type = ?');
      args.add(typeChoisi.valeur);
    }
    if (reservablesSeulement) {
      conditions.add("v.statut = 'disponible'");
    }
    final max = prixMax ?? f.prixMax;
    if (max != null) {
      conditions.add('v.prix_par_jour <= ?');
      args.add(max);
    }
    if (f.prixMin != null) {
      conditions.add('v.prix_par_jour >= ?');
      args.add(f.prixMin);
    }
    if (f.anneeMin != null) {
      conditions.add('v.annee >= ?');
      args.add(f.anneeMin);
    }
    if (f.carburant != null) {
      conditions.add('v.carburant = ?');
      args.add(f.carburant!.valeur);
    }
    if (f.boite != null) {
      conditions.add('v.boite = ?');
      args.add(f.boite!.valeur);
    }
    if (f.placesMin != null) {
      conditions.add('v.places >= ?');
      args.add(f.placesMin);
    }
    if (f.disponibleDu != null && f.disponibleAu != null) {
      final du = dateIso(f.disponibleDu!);
      final au = dateIso(f.disponibleAu!);
      conditions.add('''NOT EXISTS (SELECT 1 FROM location_vehicule l
          WHERE l.vehicule_id = v.id AND l.statut <> 'annulee'
            AND l.date_debut <= ? AND IFNULL(l.date_retour_reelle, l.date_fin) >= ?)
        AND NOT EXISTS (SELECT 1 FROM blocage_vehicule b
          WHERE b.vehicule_id = v.id AND b.date_debut <= ? AND b.date_fin >= ?)''');
      args.addAll([au, du, au, du]);
    }
    final r = (recherche ?? f.recherche)?.trim() ?? '';
    if (r.isNotEmpty) {
      conditions.add(
          "(v.marque || ' ' || v.modele || ' ' || IFNULL(v.immatriculation, '') || ' ' || "
          "IFNULL(v.couleur, '') || ' ' || IFNULL(v.adresse, '')) LIKE ? COLLATE NOCASE");
      args.add('%$r%');
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final ordre = switch (f.tri) {
      TriVehicule.prixCroissant => 'v.prix_par_jour, v.marque COLLATE NOCASE',
      TriVehicule.prixDecroissant => 'v.prix_par_jour DESC, v.marque COLLATE NOCASE',
      TriVehicule.popularite => 'nb_locations DESC, note_moyenne DESC, v.marque COLLATE NOCASE',
      _ => 'v.type, v.marque COLLATE NOCASE, v.modele COLLATE NOCASE',
    };
    final rows = await db.rawQuery('$_selectVehicule $where ORDER BY $ordre', args);
    final liste = rows.map(Vehicule.fromMap).toList();
    if (f.tri == TriVehicule.distance && f.aPositionRef) {
      // Distance calculée en Dart (haversine) ; véhicules sans position en fin de liste.
      double d(Vehicule v) => v.aPosition
          ? distanceKm(f.latitudeRef!, f.longitudeRef!, v.latitude!, v.longitude!)
          : double.infinity;
      liste.sort((a, b) => d(a).compareTo(d(b)));
    }
    return liste;
  }

  Future<Vehicule?> vehicule(int id) async {
    final db = await _db.database;
    final auj = dateIso(DateTime.now());
    final rows = await db.rawQuery(
        '$_selectVehicule WHERE v.id = ? LIMIT 1', [auj, auj, id]);
    return rows.isEmpty ? null : Vehicule.fromMap(rows.first);
  }

  /// Lève [ArgumentError] si une règle n'est pas respectée
  /// (le formulaire appelle [Vehicule.verifier] avant pour afficher le message).
  Future<int> creerVehicule(Vehicule v) async {
    _controler(v);
    final db = await _db.database;
    return db.insert('vehicule', v.toMap());
  }

  Future<void> modifierVehicule(Vehicule v) async {
    _controler(v);
    final db = await _db.database;
    await db.update('vehicule', v.toMap(), where: 'id = ?', whereArgs: [v.id]);
  }

  /// Variante pour les écrans : renvoie un message (règle ou immatriculation
  /// déjà utilisée) au lieu de lever une exception, ou null si enregistré.
  Future<String?> enregistrerVehicule(Vehicule v) async {
    final erreur = v.verifier();
    if (erreur != null) return erreur;
    try {
      if (v.id == null) {
        await creerVehicule(v);
      } else {
        await modifierVehicule(v);
      }
      return null;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return 'Cette immatriculation existe déjà';
      return 'Enregistrement impossible';
    }
  }

  Future<void> changerStatutVehicule(int id, StatutVehicule statut) async {
    final db = await _db.database;
    await db.update('vehicule', {'statut': statut.valeur},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Les locations de ce véhicule sont supprimées avec lui (ON DELETE CASCADE).
  Future<void> supprimerVehicule(int id) async {
    final db = await _db.database;
    await db.delete('vehicule', where: 'id = ?', whereArgs: [id]);
  }

  void _controler(Vehicule v) {
    final erreur = v.verifier();
    if (erreur != null) throw ArgumentError(erreur);
  }

  /// Périodes indisponibles à venir d'un véhicule : locations non annulées
  /// (fin = retour réel s'il a eu lieu, sinon date prévue) et dates bloquées.
  /// [exclureId] : location en cours de modification (ses propres dates restent libres).
  Future<List<(DateTime, DateTime)>> periodesReservees(int vehiculeId,
      {int? exclureId}) async {
    final db = await _db.database;
    final auj = dateIso(DateTime.now());
    final rows = await db.rawQuery('''
      SELECT date_debut, IFNULL(date_retour_reelle, date_fin) AS fin
      FROM location_vehicule
      WHERE vehicule_id = ? AND statut <> 'annulee' AND id <> ?
        AND IFNULL(date_retour_reelle, date_fin) >= ?
      UNION ALL
      SELECT date_debut, date_fin AS fin FROM blocage_vehicule
      WHERE vehicule_id = ? AND date_fin >= ?
      ORDER BY date_debut
    ''', [vehiculeId, exclureId ?? -1, auj, vehiculeId, auj]);
    return [
      for (final r in rows)
        (
          DateTime.parse(r['date_debut'] as String),
          DateTime.parse(r['fin'] as String),
        ),
    ];
  }

  /// Chevauchement inclusif : deux locations partageant un jour sont en conflit.
  /// Un jour bloqué par l'administrateur n'est pas libre non plus.
  Future<bool> estLibre(int vehiculeId, DateTime debut, DateTime fin,
      {int? exclureId, DatabaseExecutor? executeur}) async {
    final db = executeur ?? await _db.database;
    final f = dateIso(fin);
    final d = dateIso(debut);
    final occupe = await db.rawQuery('''
      SELECT id FROM location_vehicule
      WHERE vehicule_id = ? AND statut <> 'annulee' AND id <> ?
        AND date_debut <= ? AND IFNULL(date_retour_reelle, date_fin) >= ?
      UNION ALL
      SELECT id FROM blocage_vehicule
      WHERE vehicule_id = ? AND date_debut <= ? AND date_fin >= ?
      LIMIT 1
    ''', [vehiculeId, exclureId ?? -1, f, d, vehiculeId, f, d]);
    return occupe.isEmpty;
  }

  // ------------------------------------------------------------------
  // Dates bloquées (administrateur)
  // ------------------------------------------------------------------

  Future<List<BlocageVehicule>> blocagesDe(int vehiculeId) async {
    final db = await _db.database;
    final rows = await db.query('blocage_vehicule',
        where: 'vehicule_id = ? AND date_fin >= ?',
        whereArgs: [vehiculeId, dateIso(DateTime.now())],
        orderBy: 'date_debut');
    return rows.map(BlocageVehicule.fromMap).toList();
  }

  /// Bloque une période ; refusé si une location non annulée la recoupe déjà.
  Future<String?> ajouterBlocage(BlocageVehicule b) async {
    final erreur = b.verifier();
    if (erreur != null) return erreur;
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final conflit = await txn.rawQuery('''
        SELECT 1 FROM location_vehicule
        WHERE vehicule_id = ? AND statut <> 'annulee'
          AND date_debut <= ? AND IFNULL(date_retour_reelle, date_fin) >= ?
        LIMIT 1
      ''', [b.vehiculeId, dateIso(b.dateFin), dateIso(b.dateDebut)]);
      if (conflit.isNotEmpty) {
        return 'Des locations existent sur cette période : annulez-les d\'abord';
      }
      await txn.insert('blocage_vehicule', b.toMap());
      return null;
    });
  }

  Future<void> supprimerBlocage(int id) async {
    final db = await _db.database;
    await db.delete('blocage_vehicule', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Entretien, contrat, avis
  // ------------------------------------------------------------------

  /// Révision faite : le compteur de référence repart du kilométrage actuel.
  Future<bool> marquerRevision(int vehiculeId) async {
    final db = await _db.database;
    final n = await db.rawUpdate('''
      UPDATE vehicule SET km_derniere_revision = kilometrage
      WHERE id = ? AND kilometrage IS NOT NULL
    ''', [vehiculeId]);
    return n > 0;
  }

  /// Signature électronique du contrat : date et tracé (traits normalisés 0..1, en JSON).
  /// Refusée si la location est annulée, sans trait, ou déjà signée.
  Future<bool> signerContrat(int locationId, List<List<(double, double)>> traits) async {
    if (traits.every((t) => t.isEmpty)) return false;
    final db = await _db.database;
    final n = await db.rawUpdate('''
      UPDATE location_vehicule SET contrat_signe_le = ?, signature = ?
      WHERE id = ? AND statut <> 'annulee' AND contrat_signe_le IS NULL
    ''', [
      DateTime.now().toUtc().toIso8601String(),
      jsonEncode([
        for (final t in traits)
          [
            for (final (x, y) in t) [_arrondi4(x), _arrondi4(y)],
          ],
      ]),
      locationId,
    ]);
    return n > 0;
  }

  /// Tracé de la signature enregistrée (liste vide si non signée).
  Future<List<List<(double, double)>>> signatureDe(int locationId) async {
    final db = await _db.database;
    final rows = await db.query('location_vehicule',
        columns: ['signature'], where: 'id = ?', whereArgs: [locationId], limit: 1);
    final brut = rows.isEmpty ? null : rows.first['signature'] as String?;
    if (brut == null) return const [];
    try {
      final json = jsonDecode(brut);
      return [
        for (final t in json as List)
          [
            for (final p in t as List)
              (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
          ],
      ];
    } catch (_) {
      return const []; // tracé corrompu : contrat régénéré sans dessin
    }
  }

  static double _arrondi4(double v) => (v * 10000).round() / 10000;

  Future<LocationVehicule?> location(int id) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT l.*, v.marque || ' ' || v.modele AS nom_vehicule, v.type AS type_vehicule,
        v.photos AS photos_vehicule, vo.titre AS titre_voyage,
        u.prenom || ' ' || u.nom AS nom_client, u.email AS email_client
      FROM location_vehicule l
      JOIN vehicule v ON v.id = l.vehicule_id
      JOIN voyage vo ON vo.id = l.voyage_id
      JOIN utilisateur u ON u.id = vo.utilisateur_id
      WHERE l.id = ? LIMIT 1
    ''', [id]);
    return rows.isEmpty ? null : LocationVehicule.fromMap(rows.first);
  }

  /// Avis du forum sur un véhicule (résumé par l'IA, affichage).
  Future<List<({int note, String? commentaire})>> avisVehicule(int vehiculeId) async {
    final db = await _db.database;
    final rows = await db.query('avis',
        columns: ['note', 'commentaire'],
        where: "cible_type = 'location' AND cible_id = ?",
        whereArgs: [vehiculeId],
        orderBy: 'cree_le DESC',
        limit: 50);
    return [
      for (final r in rows) (note: r['note'] as int, commentaire: r['commentaire'] as String?),
    ];
  }

  // ------------------------------------------------------------------
  // Locations
  // ------------------------------------------------------------------

  static const String _selectLocation = '''
    SELECT l.*, v.marque || ' ' || v.modele AS nom_vehicule, v.type AS type_vehicule,
      v.photos AS photos_vehicule, vo.titre AS titre_voyage
    FROM location_vehicule l
    JOIN vehicule v ON v.id = l.vehicule_id
    JOIN voyage vo ON vo.id = l.voyage_id
  ''';

  /// Statut affiché, calculé en SQL comme [LocationVehicule.statutEffectif]
  /// (paramètre : date du jour ISO).
  static const String _statutEffectifSql = '''
    CASE
      WHEN l.statut IN ('annulee', 'en_attente') THEN l.statut
      WHEN l.date_retour_reelle IS NOT NULL OR l.statut = 'terminee' THEN 'terminee'
      WHEN l.date_debut > ? THEN 'confirmee'
      ELSE 'en_cours'
    END
  ''';

  /// Locations rattachées aux voyages de l'utilisateur (annulées à la fin).
  Future<List<LocationVehicule>> locationsDe(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_selectLocation WHERE vo.utilisateur_id = ? '
        "ORDER BY l.statut = 'annulee', l.date_debut, l.id",
        [utilisateurId]);
    return rows.map(LocationVehicule.fromMap).toList();
  }

  /// Vue administrateur : toutes les locations avec le nom et l'e-mail du client.
  /// [statut] filtre sur le statut AFFICHÉ (en cours, terminée…), pas le statut stocké.
  Future<List<LocationVehicule>> toutesLesLocations(
      {StatutLocation? statut, int? vehiculeId}) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (statut != null) {
      conditions.add('($_statutEffectifSql) = ?');
      args
        ..add(dateIso(DateTime.now()))
        ..add(statut.valeur);
    }
    if (vehiculeId != null) {
      conditions.add('l.vehicule_id = ?');
      args.add(vehiculeId);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT l.*, v.marque || ' ' || v.modele AS nom_vehicule, v.type AS type_vehicule,
        v.photos AS photos_vehicule, vo.titre AS titre_voyage,
        u.prenom || ' ' || u.nom AS nom_client, u.email AS email_client
      FROM location_vehicule l
      JOIN vehicule v ON v.id = l.vehicule_id
      JOIN voyage vo ON vo.id = l.voyage_id
      JOIN utilisateur u ON u.id = vo.utilisateur_id
      $where
      ORDER BY l.date_debut DESC, l.id DESC
    ''', args);
    return rows.map(LocationVehicule.fromMap).toList();
  }

  /// Enregistre (ajout ou modification) après contrôle, dans une transaction :
  /// véhicule disponible, options autorisées pour son type, pas de chevauchement,
  /// prix = (prix_par_jour + options) x jours, caution recopiée du véhicule.
  /// Si [utilisateurId] est donné, le voyage (et la location modifiée) doivent lui appartenir.
  /// Renvoie un message d'erreur, ou null si tout est correct.
  Future<String?> enregistrer(LocationVehicule l, {int? utilisateurId}) async {
    final periode = LocationVehicule.verifierPeriode(l.dateDebut, l.dateFin);
    if (periode != null) return periode;
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      if (utilisateurId != null) {
        final voyage = await txn.query('voyage',
            columns: ['id'],
            where: 'id = ? AND utilisateur_id = ?',
            whereArgs: [l.voyageId, utilisateurId],
            limit: 1);
        if (voyage.isEmpty) return 'Ce voyage ne vous appartient pas';
        if (l.id != null && !await _appartient(txn, l.id!, utilisateurId)) {
          return 'Location introuvable';
        }
      }
      if (l.id != null) {
        final existante = await txn.query('location_vehicule',
            columns: ['statut', 'date_retour_reelle', 'contrat_signe_le'],
            where: 'id = ?',
            whereArgs: [l.id],
            limit: 1);
        if (existante.isEmpty) return 'Location introuvable';
        if (existante.first['statut'] == StatutLocation.annulee.valeur ||
            existante.first['date_retour_reelle'] != null) {
          return 'Une location annulée ou clôturée ne se modifie plus';
        }
        if (existante.first['contrat_signe_le'] != null) {
          return 'Le contrat est signé : la location ne se modifie plus';
        }
      }
      final permis = LocationVehicule.verifierPermis(l.numeroPermis, obligatoire: false);
      if (permis != null) return permis;

      final vehiculeRows = await txn.query('vehicule',
          where: 'id = ?', whereArgs: [l.vehiculeId], limit: 1);
      if (vehiculeRows.isEmpty) return 'Véhicule introuvable';
      final vehicule = Vehicule.fromMap(vehiculeRows.first);
      if (!vehicule.disponible) {
        return 'Ce véhicule est actuellement indisponible (${vehicule.statut.libelle.toLowerCase()})';
      }
      final type = vehicule.type;
      for (final o in l.options) {
        if (!o.autorisePour(type)) {
          return 'Option « ${o.libelle} » indisponible pour une ${type.libelle.toLowerCase()}';
        }
      }
      if (!await estLibre(l.vehiculeId, l.dateDebut, l.dateFin,
          exclureId: l.id, executeur: txn)) {
        return 'Ce véhicule est déjà réservé sur une partie de ces dates';
      }

      final prix = LocationVehicule.calculerPrixDynamique(
        regles: vehicule.reglesTarif,
        prixParJour: vehicule.prixParJour,
        options: l.options.toSet(),
        debut: l.dateDebut,
        fin: l.dateFin,
      );
      final valeurs = {
        ...l.toMap(),
        'prix_total': prix.total,
        'caution': vehicule.caution,
      };
      if (l.id == null) {
        await txn.insert('location_vehicule', valeurs);
      } else {
        valeurs.remove('cree_le');
        await txn.update('location_vehicule', valeurs,
            where: 'id = ?', whereArgs: [l.id]);
      }
      return null;
    });
  }

  /// Annulation par le propriétaire : la ligne reste (historique), les dates sont libérées.
  Future<bool> annulerLocation(int id, int utilisateurId) async {
    final db = await _db.database;
    final n = await db.rawUpdate('''
      UPDATE location_vehicule SET statut = 'annulee'
      WHERE id = ? AND statut <> 'annulee' AND date_retour_reelle IS NULL
        AND voyage_id IN (SELECT id FROM voyage WHERE utilisateur_id = ?)
    ''', [id, utilisateurId]);
    return n > 0;
  }

  /// Annulation par l'administrateur (écran protégé par GardeAdmin) :
  /// toute location non annulée et non clôturée.
  Future<bool> annulerLocationAdmin(int id) async {
    final db = await _db.database;
    final n = await db.rawUpdate('''
      UPDATE location_vehicule SET statut = 'annulee'
      WHERE id = ? AND statut <> 'annulee' AND date_retour_reelle IS NULL
    ''', [id]);
    return n > 0;
  }

  /// Retour du véhicule, dans une transaction :
  /// - interdit si la location est annulée ou déjà clôturée ;
  /// - retour entre la prise en charge et aujourd'hui ;
  /// - voiture / moto : km_retour >= km_depart (km_depart = compteur du véhicule
  ///   au moment du retour, s'il n'a pas été saisi avant) ; bicyclette : pas de kilométrage ;
  /// - pénalité = jours de retard x prix_par_jour x 1,5 ; statut « terminee » ;
  /// - le compteur du véhicule est mis à jour avec km_retour.
  /// Renvoie un message d'erreur, ou null si la location est clôturée.
  Future<String?> cloturerLocation(int id,
      {required DateTime dateRetour, int? kmRetour}) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final rows = await txn.rawQuery('''
        SELECT l.*, v.type AS type_vehicule, v.prix_par_jour AS prix_jour_vehicule,
          v.kilometrage AS km_vehicule
        FROM location_vehicule l JOIN vehicule v ON v.id = l.vehicule_id
        WHERE l.id = ? LIMIT 1
      ''', [id]);
      if (rows.isEmpty) return 'Location introuvable';
      final l = LocationVehicule.fromMap(rows.first);
      if (l.annulee) return 'Une location annulée ne peut pas être clôturée';
      if (l.cloturee) return 'Cette location est déjà clôturée';

      final retour = dateJour(dateRetour);
      if (retour.isBefore(dateJour(l.dateDebut))) {
        return 'Le retour ne peut pas précéder la prise en charge';
      }
      if (retour.isAfter(dateJour(DateTime.now()))) {
        return 'La date de retour ne peut pas être dans le futur';
      }

      final type = l.typeVehicule ?? TypeVehicule.voiture;
      int? kmDepart;
      if (!type.motorise) {
        if (kmRetour != null) return 'Une bicyclette n\'a pas de kilométrage';
      } else {
        kmDepart = l.kmDepart ?? rows.first['km_vehicule'] as int?;
        if (kmRetour == null && kmDepart != null) {
          return 'Indiquez le kilométrage au retour';
        }
        if (kmRetour != null) {
          if (kmRetour < 0) return 'Kilométrage invalide';
          if (kmDepart != null && kmRetour < kmDepart) {
            return 'Le kilométrage au retour ($kmRetour km) est inférieur '
                'à celui du départ ($kmDepart km)';
          }
        }
      }

      final prixJour = (rows.first['prix_jour_vehicule'] as num).toDouble();
      final penalite = LocationVehicule.calculerPenalite(
          finPrevue: l.dateFin, retour: retour, prixParJour: prixJour);

      final n = await txn.rawUpdate('''
        UPDATE location_vehicule
        SET statut = 'terminee', date_retour_reelle = ?, km_depart = ?, km_retour = ?,
            penalite = ?
        WHERE id = ? AND statut <> 'annulee' AND date_retour_reelle IS NULL
      ''', [dateIso(retour), kmDepart, kmRetour, penalite, id]);
      if (n == 0) return 'Cette location est déjà clôturée';

      if (type.motorise && kmRetour != null) {
        await txn.rawUpdate('''
          UPDATE vehicule SET kilometrage = ?
          WHERE id = ? AND (kilometrage IS NULL OR kilometrage <= ?)
        ''', [kmRetour, l.vehiculeId, kmRetour]);
      }
      return null;
    });
  }

  Future<void> supprimerLocation(int id) async {
    final db = await _db.database;
    await db.delete('location_vehicule', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> _appartient(DatabaseExecutor db, int locationId, int utilisateurId) async {
    final rows = await db.rawQuery('''
      SELECT 1 FROM location_vehicule l JOIN voyage vo ON vo.id = l.voyage_id
      WHERE l.id = ? AND vo.utilisateur_id = ? LIMIT 1
    ''', [locationId, utilisateurId]);
    return rows.isNotEmpty;
  }

  // ------------------------------------------------------------------
  // Statistiques (onglet admin « Réservations »)
  // ------------------------------------------------------------------

  /// Indicateurs calculés en SQL. [aujourdhui] sert aux tests (défaut : maintenant).
  Future<StatistiquesLocation> statistiques({DateTime? aujourdhui}) async {
    final db = await _db.database;
    final auj = dateJour(aujourdhui ?? DateTime.now());
    final aujIso = dateIso(auj);
    final debutFenetre = dateIso(
        auj.subtract(const Duration(days: StatistiquesLocation.periodeJours - 1)));

    final compteurs = (await db.rawQuery('''
      SELECT
        COUNT(*) AS actives,
        IFNULL(SUM(CASE WHEN date_debut <= ? THEN 1 ELSE 0 END), 0) AS en_cours,
        IFNULL(SUM(CASE WHEN date_fin < ? THEN 1 ELSE 0 END), 0) AS en_retard
      FROM location_vehicule
      WHERE statut NOT IN ('annulee', 'terminee') AND date_retour_reelle IS NULL
    ''', [aujIso, aujIso])).first;

    final ca = (await db.rawQuery('''
      SELECT IFNULL(SUM(prix_total + penalite), 0) AS ca
      FROM location_vehicule WHERE statut <> 'annulee'
    ''')).first;

    final top = await db.rawQuery('''
      SELECT v.marque || ' ' || v.modele AS nom, COUNT(*) AS nb
      FROM location_vehicule l JOIN vehicule v ON v.id = l.vehicule_id
      WHERE l.statut <> 'annulee'
      GROUP BY l.vehicule_id
      ORDER BY nb DESC, SUM(l.prix_total) DESC
      LIMIT 1
    ''');

    // Jours loués dans la fenêtre = intersection [début, fin effective] ∩ fenêtre.
    final occupation = await db.rawQuery('''
      SELECT v.type AS type, COUNT(DISTINCT v.id) AS nb_vehicules,
        IFNULL(SUM(MAX(0,
          julianday(MIN(IFNULL(l.date_retour_reelle, l.date_fin), ?))
          - julianday(MAX(l.date_debut, ?)) + 1)), 0) AS jours_loues
      FROM vehicule v
      LEFT JOIN location_vehicule l ON l.vehicule_id = v.id AND l.statut <> 'annulee'
        AND l.date_debut <= ? AND IFNULL(l.date_retour_reelle, l.date_fin) >= ?
      GROUP BY v.type
    ''', [aujIso, debutFenetre, aujIso, debutFenetre]);

    final revenus = await db.rawQuery('''
      SELECT v.type AS type, IFNULL(SUM(l.prix_total + l.penalite), 0) AS ca
      FROM location_vehicule l JOIN vehicule v ON v.id = l.vehicule_id
      WHERE l.statut <> 'annulee'
      GROUP BY v.type
    ''');

    final flotte = (await db.rawQuery('''
      SELECT
        IFNULL(SUM(CASE WHEN statut = 'maintenance' THEN 1 ELSE 0 END), 0) AS maintenance,
        IFNULL(SUM(CASE WHEN kilometrage IS NOT NULL AND km_derniere_revision IS NOT NULL
          AND kilometrage - km_derniere_revision >= intervalle_revision THEN 1 ELSE 0 END), 0)
          AS revisions
      FROM vehicule
    ''')).first;

    final taux = <TypeVehicule, double>{};
    for (final r in occupation) {
      final nb = r['nb_vehicules'] as int;
      if (nb == 0) continue;
      final jours = (r['jours_loues'] as num).toDouble();
      final t = jours / (nb * StatistiquesLocation.periodeJours);
      taux[TypeVehicule.depuis(r['type'] as String?)] = t > 1 ? 1.0 : t;
    }

    return StatistiquesLocation(
      actives: compteurs['actives'] as int,
      enCours: compteurs['en_cours'] as int,
      enRetard: compteurs['en_retard'] as int,
      chiffreAffaires: (ca['ca'] as num).toDouble(),
      vehiculePlusLoue: top.isEmpty ? null : top.first['nom'] as String,
      locationsVehiculePlusLoue: top.isEmpty ? 0 : top.first['nb'] as int,
      tauxOccupation: taux,
      revenusParType: {
        for (final r in revenus)
          TypeVehicule.depuis(r['type'] as String?): (r['ca'] as num).toDouble(),
      },
      enMaintenance: flotte['maintenance'] as int,
      revisionsDues: flotte['revisions'] as int,
    );
  }
}

