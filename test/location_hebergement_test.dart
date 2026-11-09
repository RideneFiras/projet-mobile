import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/core/services/gemini_service.dart';
import 'package:projet_mobile/core/services/geocodage_service.dart';
import 'package:projet_mobile/core/services/hugging_face_service.dart';
import 'package:projet_mobile/core/utils/dates.dart';
import 'package:projet_mobile/core/utils/geo.dart';
import 'package:projet_mobile/core/utils/tarification.dart';
import 'package:projet_mobile/modules/forum/forum_repository.dart';
import 'package:projet_mobile/modules/forum/models/avis.dart';
import 'package:projet_mobile/modules/hebergement/hebergement_ia_service.dart';
import 'package:projet_mobile/modules/hebergement/hebergement_repository.dart';
import 'package:projet_mobile/modules/hebergement/models/blocage_hebergement.dart';
import 'package:projet_mobile/modules/hebergement/models/filtres_hebergement.dart';
import 'package:projet_mobile/modules/hebergement/models/hebergement.dart';
import 'package:projet_mobile/modules/hebergement/models/reservation_hebergement.dart';
import 'package:projet_mobile/modules/location/contrat_location.dart';
import 'package:projet_mobile/modules/location/location_email_service.dart';
import 'package:projet_mobile/modules/location/location_ia_service.dart';
import 'package:projet_mobile/modules/location/location_repository.dart';
import 'package:projet_mobile/modules/location/models/blocage_vehicule.dart';
import 'package:projet_mobile/modules/location/models/filtres_vehicule.dart';
import 'package:projet_mobile/modules/location/models/location_vehicule.dart';
import 'package:projet_mobile/modules/location/models/option_location.dart';
import 'package:projet_mobile/modules/location/models/statistiques_location.dart';
import 'package:projet_mobile/modules/location/models/vehicule.dart';
import 'package:projet_mobile/modules/location/suivi_simulateur.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:projet_mobile/modules/voyage/models/voyage.dart';
import 'package:projet_mobile/modules/voyage/voyage_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Version 2 des modules location (voiture / moto / bicyclette) et hébergement
/// (étoiles, équipements, chambres, avis), version 3 de la location (options,
/// clôture, vue admin, statistiques, géocodage, e-mail), version 4 (tarification
/// dynamique, blocages, filtres, entretien, contrat PDF, suivi, IA, check-in,
/// riad, types de chambre) + migrations.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
  });

  Future<int> creerUtilisateur(String email) async {
    await UserRepository().inscrire(
      nom: 'Test',
      prenom: 'Voyageur',
      email: email,
      telephone: '+216 20 000 000',
      motDePasse: 'Test1234',
      role: Role.traveller,
    );
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('utilisateur',
        columns: ['id'], where: 'email = ?', whereArgs: [email], limit: 1);
    return rows.first['id'] as int;
  }

  Future<int> creerVoyage(int userId) => VoyageRepository().creer(Voyage(
        titre: 'Djerba',
        destination: 'Djerba',
        dateDebut: DateTime(2030, 7, 1),
        dateFin: DateTime(2030, 7, 20),
        budget: 1000,
        statut: StatutVoyage.planifie,
        utilisateurId: userId,
      ));

  group('Véhicules : règles par type', () {
    test('Voiture sans immatriculation refusée, bicyclette sans immatriculation acceptée', () {
      const voiture = Vehicule(marque: 'Kia', modele: 'Picanto', prixParJour: 60);
      expect(voiture.verifier(), isNotNull);
      expect(voiture.copyWith(immatriculation: '180 TU 1234').verifier(), isNull);

      const velo = Vehicule(
          type: TypeVehicule.bicyclette,
          marque: 'Btwin',
          modele: 'Riverside',
          carburant: Carburant.aucun,
          prixParJour: 8);
      expect(velo.verifier(), isNull);
      expect(velo.places, 1);
      expect(velo.copyWith(immatriculation: '12 TU 1').verifier(), isNotNull);
      expect(velo.copyWith(carburant: Carburant.diesel).verifier(), isNotNull);
    });

    test('Moto : boîte obligatoire, 2 places au maximum', () {
      const moto = Vehicule(
          type: TypeVehicule.moto,
          marque: 'Yamaha',
          modele: 'MT-07',
          immatriculation: '55 TU 8899',
          prixParJour: 70);
      expect(moto.verifier(), isNotNull); // pas de boîte
      final ok = moto.copyWith(boite: Boite.manuelle);
      expect(ok.verifier(), isNull);
      expect(ok.copyWith(places: 3).verifier(), isNotNull);
    });

    test('toMap / fromMap conservent photos, position et type', () {
      const v = Vehicule(
        type: TypeVehicule.bicyclette,
        marque: 'Decathlon',
        modele: 'E-ST 100',
        carburant: Carburant.electrique,
        prixParJour: 15,
        photos: ['https://exemple.tn/velo.jpg', '  ', 'assets/images/kit_logo.png'],
        latitude: 33.8,
        longitude: 10.85,
        boite: Boite.manuelle, // ignorée pour une bicyclette
      );
      final relu = Vehicule.fromMap({...v.toMap(), 'id': 1});
      expect(relu.type, TypeVehicule.bicyclette);
      expect(relu.photos, ['https://exemple.tn/velo.jpg', 'assets/images/kit_logo.png']);
      expect(relu.boite, isNull);
      expect(relu.aPosition, isTrue);
    });
  });

  group('Locations', () {
    test('Filtre par type, immatriculation unique, annulation libère les dates', () async {
      final a = await creerUtilisateur('a@test.tn');
      final b = await creerUtilisateur('b@test.tn');
      final voyageA = await creerVoyage(a);
      final repo = LocationRepository();

      final scooter = await repo.creerVehicule(const Vehicule(
          type: TypeVehicule.moto,
          marque: 'Piaggio',
          modele: 'Liberty',
          immatriculation: '10 TU 2020',
          boite: Boite.automatique,
          prixParJour: 30,
          caution: 200));
      await repo.creerVehicule(const Vehicule(
          type: TypeVehicule.bicyclette,
          marque: 'Btwin',
          modele: 'Rockrider',
          carburant: Carburant.aucun,
          prixParJour: 10));

      expect(await repo.vehicules(type: TypeVehicule.moto), hasLength(1));
      expect(await repo.vehicules(recherche: 'rock'), hasLength(1));
      expect(
          await repo.enregistrerVehicule(const Vehicule(
              marque: 'Fiat',
              modele: 'Panda',
              immatriculation: '10 tu 2020', // même plaque, en minuscules
              prixParJour: 50)),
          'Cette immatriculation existe déjà');

      LocationVehicule loc(DateTime d, DateTime f) =>
          LocationVehicule(dateDebut: d, dateFin: f, voyageId: voyageA, vehiculeId: scooter);

      // B ne peut pas réserver sur le voyage de A
      expect(await repo.enregistrer(loc(DateTime(2030, 7, 2), DateTime(2030, 7, 4)),
          utilisateurId: b), isNotNull);
      expect(await repo.enregistrer(loc(DateTime(2030, 7, 2), DateTime(2030, 7, 4)),
          utilisateurId: a), isNull);

      final l = (await repo.locationsDe(a)).single;
      expect(l.prixTotal, 90.0); // 3 jours x 30
      expect(l.caution, 200.0);
      expect(l.typeVehicule, TypeVehicule.moto);

      expect(await repo.enregistrer(loc(DateTime(2030, 7, 4), DateTime(2030, 7, 5))),
          isNotNull, reason: 'chevauchement le 4');
      expect(await repo.annulerLocation(l.id!, b), isFalse);
      expect(await repo.annulerLocation(l.id!, a), isTrue);
      expect(await repo.enregistrer(loc(DateTime(2030, 7, 4), DateTime(2030, 7, 5))),
          isNull, reason: 'dates libérées par l\'annulation');

      await repo.changerStatutVehicule(scooter, StatutVehicule.maintenance);
      expect(await repo.enregistrer(loc(DateTime(2030, 7, 10), DateTime(2030, 7, 11))),
          isNotNull);
      expect(await repo.vehicules(reservablesSeulement: true), hasLength(1));
    });
  });

  group('Hébergements', () {
    const hotel = Hebergement(
      nom: 'Hôtel Médina',
      type: TypeHebergement.hotel,
      adresse: 'Rue de la Kasbah',
      ville: 'Tunis',
      etoiles: 4,
      prixParNuit: 100,
      capacite: 2,
      nbChambres: 2,
      equipements: [Equipement.wifi, Equipement.piscine],
    );

    test('Règles : étoiles réservées aux hôtels, heures HH:MM', () {
      expect(hotel.verifier(), isNull);
      const villa = Hebergement(
          nom: 'Villa', type: TypeHebergement.villa, adresse: 'Hammamet',
          prixParNuit: 300, etoiles: 3);
      expect(villa.verifier(), isNotNull);
      const horaires = Hebergement(
          nom: 'X', adresse: 'Y', prixParNuit: 10, heureArrivee: '25:00');
      expect(horaires.verifier(), isNotNull);
      expect(TypeHebergement.depuis("Maison d'hôtes"), TypeHebergement.maisonHotes);
    });

    test('Capacité, chambres libres, prix x chambres, filtre équipements', () async {
      final a = await creerUtilisateur('o@test.tn');
      final voyage = await creerVoyage(a);
      final repo = HebergementRepository();
      final id = await repo.creerHebergement(hotel);

      ReservationHebergement sejour(DateTime arr, DateTime dep,
              {int personnes = 2, int chambres = 1}) =>
          ReservationHebergement(
            dateArrivee: arr,
            dateDepart: dep,
            nbPersonnes: personnes,
            nbChambres: chambres,
            voyageId: voyage,
            hebergementId: id,
          );

      // 5 personnes dans 2 chambres de 2 : refusé
      expect(await repo.enregistrerSejour(
          sejour(DateTime(2030, 7, 1), DateTime(2030, 7, 3), personnes: 5, chambres: 2),
          utilisateurId: a), isNotNull);
      // 4 personnes, 2 chambres, 2 nuits : 100 x 2 x 2 = 400
      expect(await repo.enregistrerSejour(
          sejour(DateTime(2030, 7, 1), DateTime(2030, 7, 3), personnes: 4, chambres: 2),
          utilisateurId: a), isNull);
      expect((await repo.sejoursDe(a)).single.prixTotal, 400.0);

      // Complet le 2 ; libre le 3 (jour du départ des autres clients)
      expect(await repo.chambresLibres(id, DateTime(2030, 7, 2), DateTime(2030, 7, 4)), 0);
      expect(await repo.enregistrerSejour(
          sejour(DateTime(2030, 7, 2), DateTime(2030, 7, 4))), 'Complet sur ces dates');
      expect(await repo.enregistrerSejour(
          sejour(DateTime(2030, 7, 3), DateTime(2030, 7, 5))), isNull);

      // Annuler libère les chambres
      final premier = (await repo.sejoursDe(a)).first;
      expect(await repo.annulerSejour(premier.id!, a), isTrue);
      expect(await repo.chambresLibres(id, DateTime(2030, 7, 1), DateTime(2030, 7, 3)), 2);

      expect(await repo.hebergements(equipements: {Equipement.piscine}), hasLength(1));
      expect(await repo.hebergements(equipements: {Equipement.spa}), isEmpty);
      expect(await repo.hebergements(etoilesMin: 5), isEmpty);

      await repo.changerStatut(id, StatutHebergement.travaux);
      expect(await repo.hebergements(ouvertsSeulement: true), isEmpty);
      expect(await repo.enregistrerSejour(
          sejour(DateTime(2030, 7, 10), DateTime(2030, 7, 12))), isNotNull);
    });

    test('Note moyenne recalculée depuis les avis du forum', () async {
      final a = await creerUtilisateur('n@test.tn');
      final repo = HebergementRepository();
      final id = await repo.creerHebergement(hotel);
      for (final note in [5, 4]) {
        await ForumRepository().creerAvis(Avis(
          cible: CibleAvis.hebergement,
          cibleId: id,
          note: note,
          creeLe: DateTime.now(),
          auteurId: a,
          commentaire: 'Note $note',
        ));
      }
      final h = (await repo.hebergement(id))!;
      expect(h.nbAvis, 2);
      expect(h.noteMoyenne, 4.5);
      expect(await repo.avisDe(id), hasLength(2));
      expect((await repo.hebergements(tri: TriHebergement.note)).first.id, id);
    });
  });

  test('Migration v1 -> v2 : anciennes données converties', () async {
    // Base « version 1 » telle qu'installée avant cette mise à jour.
    final chemin = join(await getDatabasesPath(), DatabaseHelper.nomBase);
    final v1 = await openDatabase(chemin, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE vehicule (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'marque TEXT NOT NULL, modele TEXT NOT NULL, prix_par_jour REAL NOT NULL, '
          'disponible INTEGER NOT NULL DEFAULT 1)');
      await db.execute('CREATE TABLE location_vehicule (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'date_debut TEXT NOT NULL, date_fin TEXT NOT NULL, prix_total REAL NOT NULL, '
          'voyage_id INTEGER, vehicule_id INTEGER NOT NULL)');
      await db.execute('CREATE TABLE hebergement (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'nom TEXT NOT NULL, type TEXT NOT NULL, adresse TEXT NOT NULL, '
          'prix_par_nuit REAL NOT NULL)');
      await db.execute('CREATE TABLE reservation_hebergement (id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, date_arrivee TEXT NOT NULL, date_depart TEXT NOT NULL, '
          'nb_personnes INTEGER NOT NULL DEFAULT 1, prix_total REAL NOT NULL, '
          'voyage_id INTEGER, hebergement_id INTEGER NOT NULL)');
      await db.insert('vehicule',
          {'marque': 'Peugeot', 'modele': '208', 'prix_par_jour': 55, 'disponible': 0});
      await db.insert('location_vehicule', {
        'date_debut': '2026-01-01',
        'date_fin': '2026-01-03',
        'prix_total': 165,
        'voyage_id': 1,
        'vehicule_id': 1,
      });
      await db.insert('hebergement', {
        'nom': 'Dar Sidi',
        'type': "Maison d'hôtes",
        'adresse': 'Sidi Bou Saïd',
        'prix_par_nuit': 80,
      });
    });
    await v1.close();

    final repoL = LocationRepository();
    final v = (await repoL.vehicules()).single;
    expect(v.type, TypeVehicule.voiture);
    expect(v.statut, StatutVehicule.horsService);
    expect(v.places, 5);

    final h = (await HebergementRepository().hebergements()).single;
    expect(h.type, TypeHebergement.maisonHotes);
    expect(h.nbChambres, 10);
    expect(h.ouvert, isTrue);

    final db = await DatabaseHelper.instance.database;
    expect(await db.getVersion(), 4);
    // Colonnes v3 présentes avec leurs valeurs par défaut sur les anciennes lignes.
    final ancienne = LocationVehicule.fromMap(
        (await db.query('location_vehicule')).single);
    expect(ancienne.options, isEmpty);
    expect(ancienne.penalite, 0);
    expect(ancienne.statut, StatutLocation.confirmee);
    expect(ancienne.cloturee, isFalse);
    expect(v.kilometrage, isNull);
  });
  // ------------------------------------------------------------------
  // Version 3 — location : options, clôture, admin, statistiques
  // ------------------------------------------------------------------

  /// Jour relatif à aujourd'hui (constructeur DateTime : insensible aux changements d'heure).
  DateTime jour(int decalage) {
    final a = DateTime.now();
    return DateTime(a.year, a.month, a.day + decalage);
  }

  Future<int> voiture(LocationRepository repo,
          {String immat = '200 TU 1000', int? km = 1000, double prix = 50}) =>
      repo.creerVehicule(Vehicule(
          marque: 'Renault',
          modele: 'Clio',
          immatriculation: immat,
          kilometrage: km,
          prixParJour: prix,
          caution: 300));

  Future<int> velo(LocationRepository repo) => repo.creerVehicule(const Vehicule(
      type: TypeVehicule.bicyclette,
      marque: 'Btwin',
      modele: 'Elops',
      carburant: Carburant.aucun,
      prixParJour: 10));

  group('Options payantes', () {
    test('Options proposées selon le type', () {
      expect(OptionLocation.pour(TypeVehicule.voiture),
          [OptionLocation.siegeBebe, OptionLocation.gps, OptionLocation.assurance]);
      expect(OptionLocation.pour(TypeVehicule.moto),
          [OptionLocation.casque, OptionLocation.assurance]);
      expect(OptionLocation.pour(TypeVehicule.bicyclette),
          [OptionLocation.antivol, OptionLocation.assurance]);
      expect(
          LocationVehicule.calculerPrix(
              prixParJour: 50,
              options: const [OptionLocation.gps, OptionLocation.assurance],
              jours: 3),
          192.0); // (50 + 4 + 10) x 3
    });

    test('Prix recalculé par le repository, option interdite refusée, JSON relu', () async {
      final a = await creerUtilisateur('opt@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await voiture(repo);

      expect(
          await repo.enregistrer(
              LocationVehicule(
                  vehiculeId: id,
                  voyageId: voyage,
                  dateDebut: DateTime(2030, 7, 1),
                  dateFin: DateTime(2030, 7, 3),
                  options: const [OptionLocation.casque]),
              utilisateurId: a),
          contains('Casque supplémentaire'));

      expect(
          await repo.enregistrer(
              LocationVehicule(
                  vehiculeId: id,
                  voyageId: voyage,
                  dateDebut: DateTime(2030, 7, 1),
                  dateFin: DateTime(2030, 7, 3),
                  prixTotal: 1, // ignoré : le repository recalcule
                  lieuPrise: 'Aéroport Tunis-Carthage',
                  lieuRetour: 'Sousse',
                  notes: 'Arrivée 22 h',
                  options: const [OptionLocation.siegeBebe, OptionLocation.gps]),
              utilisateurId: a),
          isNull);
      final l = (await repo.locationsDe(a)).single;
      expect(l.prixTotal, 177.0); // (50 + 5 + 4) x 3
      expect(l.caution, 300.0);
      expect(l.options, [OptionLocation.siegeBebe, OptionLocation.gps]);
      expect(l.lieuRetour, 'Sousse');
    });
  });

  group('Clôture (retour du véhicule)', () {
    test('Pénalité, kilométrage et compteur du véhicule', () async {
      final a = await creerUtilisateur('clo@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await voiture(repo, km: 1000, prix: 50);
      expect(
          await repo.enregistrer(LocationVehicule(
              vehiculeId: id, voyageId: voyage, dateDebut: jour(-10), dateFin: jour(-5))),
          isNull);
      final l = (await repo.locationsDe(a)).single;
      expect(l.aCloturer, isTrue);
      expect(l.enRetard, isTrue);
      expect(l.statutEffectif, StatutLocation.enCours);

      expect(await repo.cloturerLocation(l.id!, dateRetour: jour(-3)),
          'Indiquez le kilométrage au retour');
      expect(await repo.cloturerLocation(l.id!, dateRetour: jour(-3), kmRetour: 900),
          contains('inférieur'));
      expect(await repo.cloturerLocation(l.id!, dateRetour: jour(1), kmRetour: 1200),
          contains('futur'));
      expect(await repo.cloturerLocation(l.id!, dateRetour: jour(-11), kmRetour: 1200),
          contains('précéder'));

      // 2 jours de retard x 50 x 1,5 = 150
      expect(await repo.cloturerLocation(l.id!, dateRetour: jour(-3), kmRetour: 1450),
          isNull);
      final close = (await repo.locationsDe(a)).single;
      expect(close.cloturee, isTrue);
      expect(close.statut, StatutLocation.terminee);
      expect(close.statutEffectif, StatutLocation.terminee);
      expect(close.penalite, 150.0);
      expect(close.kmDepart, 1000);
      expect(close.kmRetour, 1450);
      expect(close.totalDu, close.prixTotal + 150);
      expect((await repo.vehicule(id))!.kilometrage, 1450);

      expect(await repo.cloturerLocation(l.id!, dateRetour: jour(-3), kmRetour: 1500),
          'Cette location est déjà clôturée');
      expect(await repo.annulerLocationAdmin(l.id!), isFalse);
    });

    test('Bicyclette sans kilométrage, location annulée non clôturable', () async {
      final a = await creerUtilisateur('velo@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await velo(repo);
      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(-4), dateFin: jour(-2)));
      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(5), dateFin: jour(6)));
      final liste = await repo.locationsDe(a);

      expect(await repo.cloturerLocation(liste.first.id!, dateRetour: jour(-2), kmRetour: 5),
          contains('bicyclette'));
      expect(await repo.cloturerLocation(liste.first.id!, dateRetour: jour(-2)), isNull);
      expect((await repo.locationsDe(a)).first.penalite, 0);

      expect(await repo.annulerLocationAdmin(liste.last.id!), isTrue);
      expect(await repo.cloturerLocation(liste.last.id!, dateRetour: jour(0)),
          contains('annulée'));
    });

    test('Retour anticipé : les jours suivants redeviennent libres', () async {
      final a = await creerUtilisateur('tot@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await voiture(repo, km: null);
      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(0), dateFin: jour(10)));
      final l = (await repo.locationsDe(a)).single;
      expect(await repo.estLibre(id, jour(2), jour(3)), isFalse);
      expect(await repo.periodesReservees(id, exclureId: l.id), isEmpty);

      // Compteur inconnu (ancien véhicule) : kilométrage facultatif.
      expect(await repo.cloturerLocation(l.id!, dateRetour: jour(0)), isNull);
      expect(await repo.estLibre(id, jour(2), jour(3)), isTrue);
      final periodes = await repo.periodesReservees(id);
      expect(periodes.single.$2, jour(0));
    });
  });

  group('Vue administrateur', () {
    test('toutesLesLocations : nom du client et filtre par statut affiché', () async {
      final a = await creerUtilisateur('adm@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await voiture(repo);
      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(-2), dateFin: jour(1)));
      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(5), dateFin: jour(6)));
      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(8), dateFin: jour(9)));
      final aAnnuler = (await repo.toutesLesLocations()).first; // tri : début décroissant
      await repo.annulerLocationAdmin(aAnnuler.id!);

      final toutes = await repo.toutesLesLocations();
      expect(toutes, hasLength(3));
      expect(toutes.first.nomClient, 'Voyageur Test');
      expect(toutes.first.emailClient, 'adm@test.tn');
      expect(await repo.toutesLesLocations(statut: StatutLocation.enCours), hasLength(1));
      expect(await repo.toutesLesLocations(statut: StatutLocation.confirmee), hasLength(1));
      expect(await repo.toutesLesLocations(statut: StatutLocation.annulee), hasLength(1));
      expect(await repo.toutesLesLocations(vehiculeId: id + 99), isEmpty);
    });

    test('Statistiques : actives, chiffre d\'affaires, top véhicule, occupation 30 j', () async {
      final a = await creerUtilisateur('stat@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final clio = await voiture(repo, immat: '1 TU 1', prix: 50);
      final polo = await repo.creerVehicule(const Vehicule(
          marque: 'VW', modele: 'Polo', immatriculation: '2 TU 2', prixParJour: 60));
      final moto = await repo.creerVehicule(const Vehicule(
          type: TypeVehicule.moto,
          marque: 'Honda',
          modele: 'CB500',
          immatriculation: '3 TU 3',
          boite: Boite.manuelle,
          prixParJour: 30));

      LocationVehicule loc(int v, int d, int f, [List<OptionLocation> o = const []]) =>
          LocationVehicule(
              vehiculeId: v, voyageId: voyage, dateDebut: jour(d), dateFin: jour(f), options: o);

      await repo.enregistrer(loc(clio, -10, -6, const [OptionLocation.gps])); // 54 x 5 = 270
      final clioLoc = (await repo.toutesLesLocations(vehiculeId: clio)).single;
      await repo.cloturerLocation(clioLoc.id!, dateRetour: jour(-6), kmRetour: 1300);
      await repo.enregistrer(loc(polo, 5, 7)); // à venir : 60 x 3 = 180
      await repo.enregistrer(loc(polo, 10, 12)); // annulée ensuite
      await repo.annulerLocationAdmin(
          (await repo.toutesLesLocations(vehiculeId: polo)).first.id!);
      await repo.enregistrer(loc(moto, -4, -2)); // en retard : 30 x 3 = 90

      final s = await repo.statistiques();
      expect(s.actives, 2);
      expect(s.enCours, 1);
      expect(s.enRetard, 1);
      expect(s.chiffreAffaires, 540.0);
      expect(s.vehiculePlusLoue, 'Renault Clio');
      expect(s.locationsVehiculePlusLoue, 1);
      // Voitures : 5 jours loués / (2 véhicules x 30 j) ; moto : 3 / 30.
      expect(s.tauxOccupation[TypeVehicule.voiture], closeTo(5 / 60, 1e-9));
      expect(s.tauxOccupation[TypeVehicule.moto], closeTo(3 / 30, 1e-9));
      expect(s.tauxOccupation.containsKey(TypeVehicule.bicyclette), isFalse);
      expect(StatistiquesLocation.periodeJours, 30);
    });
  });

  group('Services réseau (simulés)', () {
    test('Géocodage : en-tête User-Agent, paramètres, réponse lue', () async {
      late http.Request recue;
      final service = GeocodageService(
          client: MockClient((requete) async {
        recue = requete;
        return http.Response.bytes(
            utf8.encode(jsonEncode([
              {'lat': '36.8065', 'lon': '10.1815', 'display_name': 'Tunis, Tunisie'},
            ])),
            200);
      }));
      final r = await service.chercherAdresse('Avenue Habib Bourguiba, Tunis');
      expect(r, isNotNull);
      expect(r!.latitude, 36.8065);
      expect(r.adresse, 'Tunis, Tunisie');
      expect(recue.headers['User-Agent'], 'TravelPlatform-ESPRIT/1.0');
      expect(recue.url.host, 'nominatim.openstreetmap.org');
      expect(recue.url.path, '/search');
      expect(recue.url.queryParameters['countrycodes'], 'tn');
      expect(recue.url.queryParameters['limit'], '1');
    });

    test('Géocodage : hors connexion et adresse introuvable -> null sans exception', () async {
      final horsLigne = GeocodageService(
          client: MockClient((_) async => throw http.ClientException('pas de réseau')));
      expect(await horsLigne.adresseDepuisPosition(36.8, 10.18), isNull);
      expect(horsLigne.derniereErreur, contains('connexion'));

      final vide = GeocodageService(client: MockClient((_) async => http.Response('[]', 200)));
      expect(await vide.chercherAdresse('zzzz introuvable'), isNull);
      expect(vide.derniereErreur, 'Adresse introuvable');

      final inverse = GeocodageService(
          client: MockClient((r) async => http.Response.bytes(
              utf8.encode(jsonEncode({'display_name': 'Sousse, Tunisie'})), 200)));
      expect(await inverse.adresseDepuisPosition(35.82, 10.63), 'Sousse, Tunisie');
    });

    test('Géocodage : une requête par seconde au maximum', () async {
      final instants = <DateTime>[];
      final service = GeocodageService(client: MockClient((_) async {
        instants.add(DateTime.now());
        return http.Response('[]', 200);
      }));
      await Future.wait([service.chercherAdresse('Tunis'), service.chercherAdresse('Sfax')]);
      expect(instants, hasLength(2));
      expect(instants[1].difference(instants[0]).inMilliseconds, greaterThanOrEqualTo(950));
    });

    final location = LocationVehicule(
      vehiculeId: 1,
      voyageId: 1,
      dateDebut: DateTime(2030, 7, 1),
      dateFin: DateTime(2030, 7, 3),
      prixTotal: 177,
      caution: 300,
      lieuPrise: 'Aéroport Tunis-Carthage',
    );

    test('E-mail : rien n\'est envoyé sans identifiants (--dart-define absents)', () async {
      var appels = 0;
      final service = LocationEmailService(
          client: MockClient((_) async {
            appels++;
            return http.Response('OK', 200);
          }),
          serviceId: '',
          templateId: '',
          clePublique: '');
      expect(service.configure, isFalse);
      expect(
          await service.envoyerConfirmation(
              email: 'a@b.tn',
              location: location,
              nomVehicule: 'Renault Clio',
              typeVehicule: TypeVehicule.voiture),
          isFalse);
      expect(appels, 0);
    });

    test('E-mail : paramètres du modèle EmailJS, échec réseau sans exception', () async {
      late Map<String, dynamic> corps;
      final service = LocationEmailService(
          client: MockClient((r) async {
            corps = jsonDecode(r.body) as Map<String, dynamic>;
            return http.Response('OK', 200);
          }),
          serviceId: 'service_test',
          templateId: 'template_test',
          clePublique: 'cle_test');
      expect(
          await service.envoyerConfirmation(
              email: 'client@test.tn',
              location: location,
              nomVehicule: 'Renault Clio',
              typeVehicule: TypeVehicule.voiture),
          isTrue);
      expect(corps['service_id'], 'service_test');
      expect(corps['user_id'], 'cle_test');
      final p = corps['template_params'] as Map<String, dynamic>;
      expect(p.keys.toSet(), {
        'to_email', 'nom_vehicule', 'type_vehicule', 'date_debut', 'date_fin',
        'prix_total', 'caution', 'lieu_prise',
      });
      expect(p['date_debut'], dateIso(DateTime(2030, 7, 1)));
      expect(p['prix_total'], '177.00');

      final horsLigne = LocationEmailService(
          client: MockClient((_) async => throw http.ClientException('pas de réseau')),
          serviceId: 's',
          templateId: 't',
          clePublique: 'k');
      expect(
          await horsLigne.envoyerConfirmation(
              email: 'client@test.tn',
              location: location,
              nomVehicule: 'Renault Clio',
              typeVehicule: TypeVehicule.voiture),
          isFalse);
    });
  });
  // ------------------------------------------------------------------
  // Version 4
  // ------------------------------------------------------------------

  group('Outils communs (v4)', () {
    test('Tarification : week-end, haute saison, remise longue durée', () {
      const regles = ReglesTarif(majorationWeekend: 10, majorationSaison: 20, remiseLongueDuree: 10);
      // Ven. 3 au dim. 5 juillet 2030 : 3 jours d'été dont 2 de week-end.
      final d = regles.calculer(100, joursEntre(DateTime(2030, 7, 5), DateTime(2030, 7, 7)));
      expect(d.unites, 3);
      expect(d.base, 300);
      expect(d.joursWeekend, 2);
      expect(d.majorationWeekend, 20);
      expect(d.majorationSaison, 60);
      expect(d.remise, 0); // moins de 7 jours
      expect(d.total, 380);
      // 7 jours de mars en semaine + week-end : remise de 10 % appliquée.
      final long = regles.calculer(100, joursEntre(DateTime(2030, 3, 4), DateTime(2030, 3, 10)));
      expect(long.remise, closeTo((700 + 20) * 0.1, 1e-9));
      expect(const ReglesTarif().calculer(50, joursEntre(jour(0), jour(2))).total, 150);
      expect(const ReglesTarif(remiseLongueDuree: 95).verifier(), isNotNull);
      // Passage à l'heure d'été (30 mars 2031) : aucun jour perdu.
      expect(joursEntre(DateTime(2031, 3, 29), DateTime(2031, 4, 1)), hasLength(4));
      expect(joursEntre(DateTime(2030, 7, 1), DateTime(2030, 7, 3), finIncluse: false),
          hasLength(2));
    });

    test('Géographie : distance et regroupement des marqueurs', () {
      expect(distanceKm(36.8065, 10.1815, 35.8256, 10.6084), closeTo(116, 5)); // Tunis-Sousse
      expect(distanceLisible(0.4), '400 m');
      expect(distanceLisible(12.34), '12,3 km');
      final points = [(36.80, 10.18), (36.81, 10.19), (33.88, 10.86)];
      final loin = regrouperPoints<(double, double)>(points,
          latitude: (p) => p.$1, longitude: (p) => p.$2, zoom: 6);
      expect(loin, hasLength(2)); // Tunis regroupée, Djerba seule
      final pres = regrouperPoints<(double, double)>(points,
          latitude: (p) => p.$1, longitude: (p) => p.$2, zoom: 16);
      expect(pres, hasLength(3));
    });

    test('Suivi simulé : le véhicule sort de la zone et l\'alerte se déclenche', () {
      final s = SimulateurSuivi(
          latitudeCentre: 36.8, longitudeCentre: 10.18, rayonKm: 2, pasKm: 1, alea: math.Random(7));
      expect(s.position.horsZone, isFalse);
      var sorti = false;
      for (var i = 0; i < 60 && !sorti; i++) {
        sorti = s.avancer().horsZone;
      }
      expect(sorti, isTrue);
    });

    test('Gemini : JSON extrait, erreurs lisibles, clé dans l\'en-tête', () async {
      expect(GeminiService.extraireJson('Voici : {"a": 1} merci'), {'a': 1});
      expect(GeminiService.extraireJson('[{"id": 2}]'), [
        {'id': 2},
      ]);
      late http.Request recue;
      final ok = GeminiService(
          cle: 'k',
          client: MockClient((r) async {
            recue = r;
            return http.Response.bytes(
                utf8.encode(jsonEncode({
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': '{"type": "moto", "prix_max": 40}'},
                        ],
                      },
                    },
                  ],
                })),
                200);
          }));
      expect(await ok.genererJson(consigne: 'c', demande: 'd'), {'type': 'moto', 'prix_max': 40});
      expect(recue.headers['x-goog-api-key'], 'k');
      expect(recue.url.queryParameters.containsKey('key'), isFalse);

      final refuse = GeminiService(cle: 'k', client: MockClient((_) async => http.Response('', 403)));
      await expectLater(refuse.genererJson(consigne: 'c', demande: 'd'),
          throwsA(isA<IaException>().having((e) => e.message, 'message', contains('refusée'))));
      final horsLigne = GeminiService(
          cle: 'k', client: MockClient((_) async => throw http.ClientException('x')));
      await expectLater(horsLigne.genererJson(consigne: 'c', demande: 'd'),
          throwsA(isA<IaException>().having((e) => e.message, 'message', contains('connexion'))));
      expect(GeminiService(cle: '').configure, isFalse);
    });

    test('Hugging Face : étiquettes triées, clé refusée', () async {
      final hf = HuggingFaceService(
          cle: 'k',
          client: MockClient((_) async => http.Response(
              jsonEncode([
                {'label': 'car', 'score': 0.4},
                {'label': 'scratch', 'score': 0.9},
              ]),
              200)));
      final e = await hf.analyser(Uint8List.fromList([1, 2, 3]), modele: 'm');
      expect(e.first.label, 'scratch');
      final lecture = LocationIaService.interpreterEtiquettes(e, TypeVehicule.voiture);
      expect(lecture.dommage, isTrue);
      expect(lecture.vehiculeVisible, isFalse); // car à 0,4 < 0,5
      expect(
          HebergementIaService.probabiliteArtificielle(
              [(label: 'artificial', score: 0.82), (label: 'human', score: 0.18)]),
          0.82);
      final refuse = HuggingFaceService(cle: 'k', client: MockClient((_) async => http.Response('', 401)));
      await expectLater(refuse.analyser(Uint8List(1), modele: 'm'), throwsA(isA<IaException>()));
    });
  });

  group('Location v4', () {
    test('Tarif dynamique appliqué par le repository, permis contrôlé', () async {
      final a = await creerUtilisateur('dyn@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await repo.creerVehicule(const Vehicule(
          marque: 'Dacia',
          modele: 'Duster',
          immatriculation: '9 TU 9',
          prixParJour: 100,
          majorationWeekend: 10,
          majorationSaison: 20));
      expect(
          await repo.enregistrer(LocationVehicule(
              vehiculeId: id,
              voyageId: voyage,
              dateDebut: DateTime(2030, 7, 5),
              dateFin: DateTime(2030, 7, 7),
              numeroPermis: '#!'),
              utilisateurId: a),
          'Numéro de permis invalide');
      expect(
          await repo.enregistrer(
              LocationVehicule(
                  vehiculeId: id,
                  voyageId: voyage,
                  dateDebut: DateTime(2030, 7, 5),
                  dateFin: DateTime(2030, 7, 7),
                  numeroPermis: '12/345678',
                  options: const [OptionLocation.gps]),
              utilisateurId: a),
          isNull);
      final l = (await repo.locationsDe(a)).single;
      expect(l.prixTotal, 392.0); // 380 (voir tarification) + GPS 4 x 3
      expect(l.numeroPermis, '12/345678');
    });

    test('Dates bloquées : réservation refusée, filtre de disponibilité', () async {
      final a = await creerUtilisateur('bloc@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await voiture(repo, immat: '5 TU 5');
      await voiture(repo, immat: '6 TU 6');
      expect(
          await repo.ajouterBlocage(BlocageVehicule(
              vehiculeId: id, dateDebut: jour(10), dateFin: jour(12), motif: 'Vidange')),
          isNull);
      expect(await repo.estLibre(id, jour(11), jour(11)), isFalse);
      expect(
          await repo.enregistrer(LocationVehicule(
              vehiculeId: id, voyageId: voyage, dateDebut: jour(9), dateFin: jour(10))),
          contains('déjà réservé'));
      expect((await repo.periodesReservees(id)).single.$1, jour(10));
      final dispo = await repo.vehicules(
          filtres: FiltresVehicule(disponibleDu: jour(11), disponibleAu: jour(11)));
      expect(dispo.map((v) => v.id), isNot(contains(id)));
      expect(dispo, hasLength(1));

      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(20), dateFin: jour(21)));
      expect(
          await repo.ajouterBlocage(
              BlocageVehicule(vehiculeId: id, dateDebut: jour(21), dateFin: jour(22))),
          contains('locations existent'));
      final b = (await repo.blocagesDe(id)).single;
      await repo.supprimerBlocage(b.id!);
      expect(await repo.estLibre(id, jour(11), jour(11)), isTrue);
    });

    test('Filtres avancés et tris', () async {
      final repo = LocationRepository();
      await repo.creerVehicule(const Vehicule(
          marque: 'Renault', modele: 'Zoe', immatriculation: '1 TU 10', annee: 2023,
          carburant: Carburant.electrique, boite: Boite.automatique, prixParJour: 90,
          latitude: 36.8, longitude: 10.18));
      await repo.creerVehicule(const Vehicule(
          marque: 'Fiat', modele: 'Doblo', immatriculation: '2 TU 20', annee: 2015,
          carburant: Carburant.diesel, places: 7, prixParJour: 70,
          latitude: 35.82, longitude: 10.63));
      await repo.creerVehicule(const Vehicule(
          type: TypeVehicule.moto, marque: 'Yamaha', modele: 'NMax', immatriculation: '3 TU 30',
          boite: Boite.automatique, prixParJour: 35));

      expect(await repo.vehicules(filtres: const FiltresVehicule(anneeMin: 2020)), hasLength(1));
      expect(await repo.vehicules(filtres: const FiltresVehicule(placesMin: 6)), hasLength(1));
      expect(await repo.vehicules(filtres: const FiltresVehicule(boite: Boite.automatique)),
          hasLength(2));
      expect(await repo.vehicules(filtres: const FiltresVehicule(prixMin: 50, prixMax: 80)),
          hasLength(1));
      expect(await repo.vehicules(recherche: '2 tu 20'), hasLength(1)); // immatriculation
      final parPrix =
          await repo.vehicules(filtres: const FiltresVehicule(tri: TriVehicule.prixCroissant));
      expect(parPrix.map((v) => v.prixParJour), [35, 70, 90]);
      // Proche de Sousse : la Doblo d'abord, la moto (sans position) en dernier.
      final proches = await repo.vehicules(
          filtres: const FiltresVehicule(
              tri: TriVehicule.distance, latitudeRef: 35.83, longitudeRef: 10.64));
      expect(proches.first.modele, 'Doblo');
      expect(proches.last.modele, 'NMax');
      expect(proches.first.estElectrique, isFalse);
      expect(proches[1].estElectrique, isTrue);
    });

    test('Entretien et statistiques de flotte', () async {
      final a = await creerUtilisateur('rev@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await repo.creerVehicule(const Vehicule(
          marque: 'Peugeot', modele: '208', immatriculation: '4 TU 40',
          kilometrage: 20000, intervalleRevision: 1000, prixParJour: 50));
      expect((await repo.vehicule(id))!.kmDerniereRevision, 20000);
      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(-3), dateFin: jour(-2)));
      final l = (await repo.locationsDe(a)).single;
      await repo.cloturerLocation(l.id!, dateRetour: jour(-2), kmRetour: 21200);
      final v = (await repo.vehicule(id))!;
      expect(v.kmDepuisRevision, 1200);
      expect(v.revisionDue, isTrue);
      final moto = await repo.creerVehicule(const Vehicule(
          type: TypeVehicule.moto, marque: 'Honda', modele: 'PCX', immatriculation: '7 TU 7',
          boite: Boite.automatique, prixParJour: 30));
      await repo.changerStatutVehicule(moto, StatutVehicule.maintenance);

      var s = await repo.statistiques();
      expect(s.revisionsDues, 1);
      expect(s.enMaintenance, 1);
      expect(s.revenusParType[TypeVehicule.voiture], 100.0);
      expect(await repo.marquerRevision(id), isTrue);
      s = await repo.statistiques();
      expect(s.revisionsDues, 0);
      expect((await repo.vehicule(id))!.revisionDue, isFalse);
    });

    test('Contrat : signature enregistrée, PDF valide, location figée', () async {
      final a = await creerUtilisateur('pdf@test.tn');
      final voyage = await creerVoyage(a);
      final repo = LocationRepository();
      final id = await voiture(repo, immat: '8 TU 80');
      await repo.enregistrer(LocationVehicule(
          vehiculeId: id, voyageId: voyage, dateDebut: jour(3), dateFin: jour(5),
          lieuPrise: 'Aéroport'));
      final l = (await repo.locationsDe(a)).single;

      expect(await repo.signerContrat(l.id!, const []), isFalse);
      final trait = [(0.1, 0.5), (0.4, 0.2), (0.9, 0.8)];
      expect(await repo.signerContrat(l.id!, [trait]), isTrue);
      expect(await repo.signerContrat(l.id!, [trait]), isFalse); // déjà signé
      expect((await repo.signatureDe(l.id!)).single, trait);
      expect(
          await repo.enregistrer(LocationVehicule(
              id: l.id, vehiculeId: id, voyageId: voyage, dateDebut: jour(3), dateFin: jour(6))),
          contains('contrat est signé'));

      final signee = (await repo.location(l.id!))!;
      expect(signee.contratSigneLe, isNotNull);
      expect(signee.nomClient, 'Voyageur Test');
      final octets = ContratLocation.genererPdf(
        location: signee,
        vehicule: (await repo.vehicule(id))!,
        nomClient: signee.nomClient!,
        signature: [trait],
        signeLe: signee.contratSigneLe,
      );
      final texte = latin1.decode(octets);
      expect(texte.startsWith('%PDF-1.4'), isTrue);
      expect(texte.trimRight().endsWith('%%EOF'), isTrue);
      expect(texte, contains('CONTRAT DE LOCATION DE VÉHICULE'));
      expect(texte, contains('Aéroport')); // accent conservé (WinAnsi)
      final debutXref = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(texte)!.group(1)!);
      expect(texte.substring(debutXref, debutXref + 4), 'xref');
      // Chaque entrée de la table xref pointe bien sur « N 0 obj ».
      final entrees = RegExp(r'(\d{10}) 00000 n ').allMatches(texte).toList();
      for (final (i, e) in entrees.indexed) {
        expect(texte.substring(int.parse(e.group(1)!)).startsWith('${i + 1} 0 obj'), isTrue);
      }
    });

    test('IA locale (sans clé) : analyse, recommandation, estimation', () async {
      final f = LocationIaService.analyseLocale(
          'Voiture familiale électrique, boîte auto, 80 DT par jour, pas cher');
      expect(f.type, TypeVehicule.voiture);
      expect(f.carburant, Carburant.electrique);
      expect(f.boite, Boite.automatique);
      expect(f.prixMax, 80);
      expect(f.placesMin, 5);
      expect(f.tri, TriVehicule.prixCroissant);
      expect(LocationIaService.analyseLocale('un vélo pour 2 personnes').type,
          TypeVehicule.bicyclette);

      const zoe = Vehicule(id: 1, marque: 'Renault', modele: 'Zoe', immatriculation: '1 TU 1',
          carburant: Carburant.electrique, prixParJour: 75);
      const clio = Vehicule(id: 2, marque: 'Renault', modele: 'Clio', immatriculation: '2 TU 2',
          prixParJour: 60);
      final reco = LocationIaService.recommandationLocale(f, [clio, zoe]);
      expect(reco.first.vehiculeId, 1);

      final ia = LocationIaService(gemini: GeminiService(cle: ''));
      expect((await ia.analyserDemande('moto 40 dt')).parIa, isFalse);
      final prix = await ia.estimerPrix(const Vehicule(
          type: TypeVehicule.bicyclette, marque: 'B', modele: 'E', carburant: Carburant.electrique,
          prixParJour: 1));
      expect(prix.parIa, isFalse);
      expect(prix.min, greaterThan(15));
      expect(prix.max, lessThan(30));
      await expectLater(ia.repondre('?', const []), throwsA(isA<IaException>()));
    });

    test('IA via Gemini (simulé) : filtres JSON validés', () async {
      final ia = LocationIaService(
          gemini: GeminiService(
              cle: 'k',
              client: MockClient((_) async => http.Response.bytes(
                  utf8.encode(jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'parts': [
                            {
                              'text': '{"type":"moto","prix_max":45,"carburant":"inconnu",'
                                  '"places_min":2,"boite":"automatique"}',
                            },
                          ],
                        },
                      },
                    ],
                  })),
                  200))));
      final r = await ia.analyserDemande('un scooter pas cher');
      expect(r.parIa, isTrue);
      expect(r.filtres.type, TypeVehicule.moto);
      expect(r.filtres.prixMax, 45);
      expect(r.filtres.carburant, isNull); // valeur inconnue ignorée
      expect(r.filtres.boite, Boite.automatique);
    });
  });

  group('Hébergement v4', () {
    const riad = Hebergement(
      nom: 'Dar El Medina',
      type: TypeHebergement.riad,
      adresse: 'Médina',
      ville: 'Tunis',
      prixParNuit: 200,
      capacite: 2,
      nbChambres: 2,
      majorationWeekend: 10,
      superficie: 300,
      regles: 'Pas d\'animaux',
      equipements: [Equipement.petitDejeuner, Equipement.wifi],
      latitude: 36.798,
      longitude: 10.171,
    );

    test('Riad, type de chambre et tarif dynamique', () async {
      final a = await creerUtilisateur('riad@test.tn');
      final voyage = await creerVoyage(a);
      final repo = HebergementRepository();
      final id = await repo.creerHebergement(riad);
      final relu = (await repo.hebergement(id))!;
      expect(relu.type, TypeHebergement.riad);
      expect(relu.superficie, 300);
      expect(relu.regles, 'Pas d\'animaux');

      // Ven. 5 -> dim. 7 juillet 2030 : nuits du vendredi et du samedi (1 de week-end).
      expect(
          await repo.enregistrerSejour(
              ReservationHebergement(
                  hebergementId: id,
                  voyageId: voyage,
                  dateArrivee: DateTime(2030, 7, 5),
                  dateDepart: DateTime(2030, 7, 7),
                  nbPersonnes: 2,
                  typeChambre: TypeChambre.suite),
              utilisateurId: a),
          isNull);
      final s = (await repo.sejoursDe(a)).single;
      expect(s.typeChambre, TypeChambre.suite);
      expect(s.prixTotal, 672.0); // 320 x 2 nuits + 10 % de 320 (samedi)
      expect(s.codeCheckin, matches(RegExp(r'^\d{6}$')));
      expect(TypeChambre.single.libelleTarif, '−20 %');
    });

    test('Fermetures, nuits complètes et filtre de disponibilité', () async {
      final a = await creerUtilisateur('ferm@test.tn');
      final voyage = await creerVoyage(a);
      final repo = HebergementRepository();
      final id = await repo.creerHebergement(riad);
      await repo.creerHebergement(const Hebergement(
          nom: 'Hôtel Lac', adresse: 'Lac 2', ville: 'Tunis', prixParNuit: 150, nbChambres: 5));

      await repo.enregistrerSejour(ReservationHebergement(
          hebergementId: id, voyageId: voyage, dateArrivee: jour(5), dateDepart: jour(7),
          nbPersonnes: 4, nbChambres: 2));
      final nuits = await repo.nuitsIndisponibles(id);
      expect(nuits, containsAll([jour(5), jour(6)]));
      expect(nuits.contains(jour(7)), isFalse); // nuit du départ libre

      final libres = await repo.hebergements(
          filtres: FiltresHebergement(arrivee: jour(6), depart: jour(8)));
      expect(libres.map((h) => h.nom), ['Hôtel Lac']);

      expect(
          await repo.ajouterBlocage(BlocageHebergement(
              hebergementId: id, dateDebut: jour(6), dateFin: jour(6))),
          contains('séjours sont réservés'));
      expect(
          await repo.ajouterBlocage(BlocageHebergement(
              hebergementId: id, dateDebut: jour(20), dateFin: jour(22), motif: 'Travaux')),
          isNull);
      expect(await repo.chambresLibres(id, jour(21), jour(23)), 0);
      expect(
          await repo.enregistrerSejour(ReservationHebergement(
              hebergementId: id, voyageId: voyage, dateArrivee: jour(19), dateDepart: jour(21))),
          'Complet sur ces dates');
      expect(await repo.nuitsIndisponibles(id), contains(jour(22)));
    });

    test('Check-in par code, check-out, réception du jour', () async {
      final a = await creerUtilisateur('chk@test.tn');
      final voyage = await creerVoyage(a);
      final repo = HebergementRepository();
      final id = await repo.creerHebergement(riad);
      await repo.enregistrerSejour(ReservationHebergement(
          hebergementId: id, voyageId: voyage, dateArrivee: jour(0), dateDepart: jour(2)));
      await repo.enregistrerSejour(ReservationHebergement(
          hebergementId: id, voyageId: voyage, dateArrivee: jour(5), dateDepart: jour(6)));
      final sejours = await repo.sejoursDe(a);
      final aujourdhui = sejours.first;
      final plusTard = sejours.last;

      expect(await repo.validerCheckIn(plusTard.id!, plusTard.codeCheckin!),
          contains('Check-in possible seulement'));
      expect(await repo.validerCheckIn(aujourdhui.id!, '000000') == null &&
              aujourdhui.codeCheckin != '000000',
          isFalse);
      expect(await repo.checkOut(aujourdhui.id!), isNotNull); // pas encore arrivé
      expect((await repo.tousLesSejours(aTraiter: true)).single.sejour.id, aujourdhui.id);
      expect(await repo.validerCheckIn(aujourdhui.id!, aujourdhui.codeCheckin!), isNull);
      expect(await repo.validerCheckIn(aujourdhui.id!, aujourdhui.codeCheckin!),
          'Le client est déjà arrivé');
      expect(await repo.annulerSejour(aujourdhui.id!, a), isFalse);
      final arrive = (await repo.sejoursDe(a)).first;
      expect(arrive.statutEffectif, StatutSejour.checkIn);
      expect(arrive.peutCheckOut, isTrue);

      expect(await repo.chambresLibres(id, jour(0), jour(1)), 1);
      expect(await repo.checkOut(aujourdhui.id!), isNull);
      expect(await repo.chambresLibres(id, jour(0), jour(1)), 2); // chambre libérée
      expect((await repo.sejoursDe(a)).first.statutEffectif, StatutSejour.checkOut);
      expect(await repo.tousLesSejours(), hasLength(2));
      expect(HebergementRepository.genererCode(math.Random(1)), matches(RegExp(r'^\d{6}$')));
    });

    test('Filtres, tris, distribution des notes', () async {
      final a = await creerUtilisateur('dist@test.tn');
      final repo = HebergementRepository();
      final id = await repo.creerHebergement(riad);
      await repo.creerHebergement(const Hebergement(
          nom: 'Camping Sahara', type: TypeHebergement.camping, adresse: 'Douz',
          prixParNuit: 40, latitude: 33.45, longitude: 9.02));
      for (final note in [5, 5, 4]) {
        await ForumRepository().creerAvis(Avis(
            cible: CibleAvis.hebergement, cibleId: id, note: note, creeLe: DateTime.now(),
            auteurId: a));
      }
      expect(await repo.distributionNotes(id), {5: 2, 4: 1, 3: 0, 2: 0, 1: 0});
      expect(await repo.hebergements(filtres: const FiltresHebergement(noteMin: 4.5)), hasLength(1));
      expect(await repo.hebergements(filtres: const FiltresHebergement(prixMin: 100)), hasLength(1));
      final proches = await repo.hebergements(
          tri: TriHebergement.distance,
          filtres: const FiltresHebergement(latitudeRef: 33.9, longitudeRef: 9.5));
      expect(proches.first.nom, 'Camping Sahara');
    });

    test('IA hébergement : analyse locale, profil, estimation, concierge simulé', () async {
      final f = HebergementIaService.analyseLocale(
          'Riad avec piscine et petit-déjeuner pour 4 personnes, 4 étoiles, 250 DT');
      expect(f.type, TypeHebergement.riad);
      expect(f.equipements, containsAll([Equipement.piscine, Equipement.petitDejeuner]));
      expect(f.personnes, 4);
      expect(f.etoilesMin, 4);
      expect(f.prixMax, 250);

      const famille = Hebergement(id: 1, nom: 'Villa', type: TypeHebergement.villa,
          adresse: 'H', prixParNuit: 300, capacite: 6,
          equipements: [Equipement.piscine, Equipement.parking, Equipement.cuisine]);
      const business = Hebergement(id: 2, nom: 'Hôtel Centre', adresse: 'T', prixParNuit: 150,
          equipements: [Equipement.wifi, Equipement.navette]);
      expect(HebergementIaService.recommandationLocale(ProfilVoyageur.famille, [business, famille])
          .first.hebergementId, 1);
      expect(HebergementIaService.recommandationLocale(ProfilVoyageur.affaires, [famille, business])
          .first.hebergementId, 2);
      final e = HebergementIaService.estimationLocale(famille);
      expect(e.min, lessThan(e.max));

      final ia = HebergementIaService(
          gemini: GeminiService(
              cle: 'k',
              client: MockClient((r) async {
                // La fiche envoyée contient les règles : le concierge n'invente rien.
                expect(r.body, contains('Pas d'));
                return http.Response.bytes(
                    utf8.encode(jsonEncode({
                      'candidates': [
                        {
                          'content': {
                            'parts': [
                              {'text': '{"reponse": "Les animaux ne sont pas acceptés."}'},
                            ],
                          },
                        },
                      ],
                    })),
                    200);
              })));
      expect(await ia.concierge('Mon chien peut venir ?', riad),
          'Les animaux ne sont pas acceptés.');
    });
  });

  test('Migration v3 -> v4 : hébergements et séjours recopiés, riad accepté', () async {
    final chemin = join(await getDatabasesPath(), DatabaseHelper.nomBase);
    final v3 = await openDatabase(chemin, version: 3, onCreate: (db, _) async {
      await db.execute('CREATE TABLE vehicule (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          "type TEXT NOT NULL DEFAULT 'voiture', marque TEXT NOT NULL, modele TEXT NOT NULL, "
          'annee INTEGER, couleur TEXT, immatriculation TEXT, '
          "carburant TEXT NOT NULL DEFAULT 'essence', boite TEXT, "
          'places INTEGER NOT NULL DEFAULT 1, kilometrage INTEGER, '
          'prix_par_jour REAL NOT NULL, caution REAL NOT NULL DEFAULT 0, '
          "photos TEXT NOT NULL DEFAULT '[]', latitude REAL, longitude REAL, adresse TEXT, "
          "description TEXT, statut TEXT NOT NULL DEFAULT 'disponible', cree_le TEXT)");
      await db.execute('CREATE TABLE location_vehicule (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'vehicule_id INTEGER NOT NULL, voyage_id INTEGER, date_debut TEXT NOT NULL, '
          'date_fin TEXT NOT NULL, prix_total REAL NOT NULL, caution REAL NOT NULL DEFAULT 0, '
          "statut TEXT NOT NULL DEFAULT 'confirmee', lieu_prise TEXT, lieu_retour TEXT, "
          "notes TEXT, options TEXT NOT NULL DEFAULT '[]', date_retour_reelle TEXT, "
          'km_depart INTEGER, km_retour INTEGER, penalite REAL NOT NULL DEFAULT 0, cree_le TEXT)');
      await db.execute('CREATE TABLE hebergement (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'nom TEXT NOT NULL, '
          "type TEXT NOT NULL DEFAULT 'hotel' CHECK (type IN ('hotel','auberge','appartement',"
          "'maison_hotes','villa','camping')), description TEXT, adresse TEXT NOT NULL, "
          'ville TEXT, latitude REAL, longitude REAL, etoiles INTEGER, '
          'prix_par_nuit REAL NOT NULL, capacite INTEGER NOT NULL DEFAULT 2, '
          "nb_chambres INTEGER NOT NULL DEFAULT 1, equipements TEXT NOT NULL DEFAULT '[]', "
          "photos TEXT NOT NULL DEFAULT '[]', telephone TEXT, "
          "heure_arrivee TEXT NOT NULL DEFAULT '15:00', heure_depart TEXT NOT NULL DEFAULT '11:00', "
          'note_moyenne REAL NOT NULL DEFAULT 0, nb_avis INTEGER NOT NULL DEFAULT 0, '
          "statut TEXT NOT NULL DEFAULT 'actif', cree_le TEXT)");
      await db.execute('CREATE TABLE reservation_hebergement (id INTEGER PRIMARY KEY '
          'AUTOINCREMENT, hebergement_id INTEGER NOT NULL, voyage_id INTEGER, '
          'date_arrivee TEXT NOT NULL, date_depart TEXT NOT NULL, '
          'nb_personnes INTEGER NOT NULL DEFAULT 1, nb_chambres INTEGER NOT NULL DEFAULT 1, '
          "prix_total REAL NOT NULL, statut TEXT NOT NULL DEFAULT 'confirmee' "
          "CHECK (statut IN ('en_attente','confirmee','en_cours','terminee','annulee')), "
          'demandes TEXT, cree_le TEXT, '
          'FOREIGN KEY (hebergement_id) REFERENCES hebergement (id) ON DELETE CASCADE)');
      await db.insert('vehicule',
          {'marque': 'Kia', 'modele': 'Rio', 'immatriculation': '1 TU 1', 'kilometrage': 5000,
           'prix_par_jour': 45});
      await db.insert('hebergement',
          {'nom': 'Hôtel Mer', 'adresse': 'Sousse', 'prix_par_nuit': 120, 'nb_chambres': 3});
      await db.insert('reservation_hebergement', {
        'hebergement_id': 1,
        'voyage_id': 1,
        'date_arrivee': '2030-07-01',
        'date_depart': '2030-07-03',
        'nb_personnes': 2,
        'prix_total': 240,
        'demandes': 'Vue mer',
      });
    });
    await v3.close();

    final db = await DatabaseHelper.instance.database;
    expect(await db.getVersion(), 4);
    final s = await db.query('reservation_hebergement');
    expect(s.single['demandes'], 'Vue mer');
    expect(s.single['type_chambre'], 'double');
    final v = (await LocationRepository().vehicules()).single;
    expect(v.kmDerniereRevision, 5000);
    expect(v.intervalleRevision, 10000);
    expect(await HebergementRepository().creerHebergement(
        const Hebergement(nom: 'Riad', type: TypeHebergement.riad, adresse: 'M', prixParNuit: 1)),
        greaterThan(1));
    // Clés étrangères réactivées après la migration : la cascade fonctionne.
    await HebergementRepository().supprimerHebergement(1);
    expect(await db.query('reservation_hebergement'), isEmpty);
    expect((await db.rawQuery('PRAGMA foreign_keys')).first.values.first, 1);
  });
}
