import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/core/utils/dates.dart';
import 'package:projet_mobile/core/utils/montants.dart';
import 'package:projet_mobile/modules/forum/forum_repository.dart';
import 'package:projet_mobile/modules/forum/models/avis.dart';
import 'package:projet_mobile/modules/forum/models/sujet_forum.dart';
import 'package:projet_mobile/modules/hebergement/hebergement_repository.dart';
import 'package:projet_mobile/modules/hebergement/models/hebergement.dart';
import 'package:projet_mobile/modules/hebergement/models/reservation_hebergement.dart';
import 'package:projet_mobile/modules/location/location_repository.dart';
import 'package:projet_mobile/modules/location/models/location_vehicule.dart';
import 'package:projet_mobile/modules/location/models/vehicule.dart';
import 'package:projet_mobile/modules/user/admin_repository.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:projet_mobile/modules/voyage/models/voyage.dart';
import 'package:projet_mobile/modules/voyage/voyage_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests des modules voyage, location, hébergement, forum et administration
/// sur la vraie base SQLite (sans émulateur) : flutter test
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
  });

  Future<int> idDe(String email) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('utilisateur',
        columns: ['id'], where: 'email = ?', whereArgs: [email], limit: 1);
    return rows.first['id'] as int;
  }

  Future<int> creerUtilisateur(String email, Role role) async {
    await UserRepository().inscrire(
      nom: 'Test',
      prenom: role.libelle,
      email: email,
      telephone: '+216 20 000 000',
      motDePasse: 'Test1234',
      role: role,
    );
    return idDe(email);
  }

  Future<int> creerVoyage(int userId, {String titre = 'Voyage test'}) {
    return VoyageRepository().creer(Voyage(
      titre: titre,
      destination: 'Djerba',
      dateDebut: DateTime(2026, 11, 10),
      dateFin: DateTime(2026, 11, 20),
      budget: 500,
      statut: StatutVoyage.planifie,
      utilisateurId: userId,
    ));
  }

  group('Dates et montants', () {
    test('Format court et ISO', () {
      expect(dateCourte(DateTime(2026, 10, 15)), '15 OCT. 2026');
      expect(dateIso(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('Voyage : fin avant début refusée, même jour accepté', () {
      expect(Voyage.verifierPeriode(DateTime(2026, 11, 10), DateTime(2026, 11, 9)),
          isNotNull);
      expect(Voyage.verifierPeriode(DateTime(2026, 11, 10), DateTime(2026, 11, 10)),
          isNull);
    });

    test('Location : jours bornes comprises (3 jours du 10 au 12)', () {
      final l = LocationVehicule(
        dateDebut: DateTime(2026, 11, 10),
        dateFin: DateTime(2026, 11, 12),
        voyageId: 1,
        vehiculeId: 1,
      );
      expect(l.jours, 3);
    });

    test('Hébergement : nuits = départ - arrivée, départ strictement après', () {
      final s = ReservationHebergement(
        dateArrivee: DateTime(2026, 11, 10),
        dateDepart: DateTime(2026, 11, 13),
        voyageId: 1,
        hebergementId: 1,
      );
      expect(s.nuits, 3);
      expect(ReservationHebergement.verifierSejour(
              DateTime(2026, 11, 10), DateTime(2026, 11, 10)),
          isNotNull);
    });

    test('Montants en dinars', () {
      expect(Montants.enCentimes('12,5'), 1250);
      expect(Montants.enCentimes('12.345'), isNull);
      expect(Montants.valider('abc'), isNotNull);
      expect(Montants.valider('', obligatoire: false), isNull);
    });
  });

  group('Voyages (CRUD)', () {
    test('Création, lecture, modification et suppression du propriétaire seulement',
        () async {
      final a = await creerUtilisateur('dhia@test.tn', Role.traveller);
      final b = await creerUtilisateur('roua@test.tn', Role.traveller);
      final repo = VoyageRepository();
      final id = await creerVoyage(a, titre: 'Djerba');

      final liste = await repo.voyagesDe(a);
      expect(liste.single.titre, 'Djerba');
      expect(liste.single.duree, 11);
      expect(await repo.voyagesDe(b), isEmpty);

      final v = liste.single;
      final modifie = Voyage(
        id: id,
        titre: 'Djerba bis',
        destination: v.destination,
        dateDebut: v.dateDebut,
        dateFin: v.dateFin,
        budget: 600,
        statut: StatutVoyage.actif,
        utilisateurId: a,
      );
      expect(await repo.modifier(modifie, b), isFalse);
      expect(await repo.modifier(modifie, a), isTrue);
      expect((await repo.voyagesDe(a)).single.titre, 'Djerba bis');

      expect(await repo.supprimer(id, b), isFalse);
      expect(await repo.supprimer(id, a), isTrue);
      expect(await repo.voyagesDe(a), isEmpty);
    });
  });

  group('Location (CRUD et règles)', () {
    test('Prix = tarif x jours, chevauchement et indisponibilité refusés', () async {
      final client = await creerUtilisateur('client@test.tn', Role.traveller);
      final voyage = await creerVoyage(client);
      final repo = LocationRepository();
      final vehiculeId = await repo.creerVehicule(
          const Vehicule(marque: 'Renault', modele: 'Clio', prixParJour: 40));

      LocationVehicule reservation(DateTime debut, DateTime fin, {int? id}) =>
          LocationVehicule(
            id: id,
            dateDebut: debut,
            dateFin: fin,
            voyageId: voyage,
            vehiculeId: vehiculeId,
          );

      // 10, 11 et 12 novembre : 3 jours à 40 DT
      expect(await repo.enregistrer(reservation(DateTime(2026, 11, 10),
          DateTime(2026, 11, 12))), isNull);
      final locations = await repo.locationsDe(client);
      expect(locations, hasLength(1));
      expect(locations.first.prixTotal, 120.0);
      expect(locations.first.nomVehicule, 'Renault Clio');

      // Le 12 novembre est déjà pris
      expect(await repo.enregistrer(reservation(DateTime(2026, 11, 12),
          DateTime(2026, 11, 14))), isNotNull);
      // Le 13 est libre
      expect(await repo.enregistrer(reservation(DateTime(2026, 11, 13),
          DateTime(2026, 11, 14))), isNull);
      // Modifier une location sans changer ses dates ne la fait pas entrer en conflit avec elle-même
      final premiere = (await repo.locationsDe(client)).first;
      expect(await repo.enregistrer(reservation(premiere.dateDebut,
          premiere.dateFin, id: premiere.id)), isNull);

      // Véhicule rendu indisponible : plus de nouvelle location
      await repo.modifierVehicule(Vehicule(
          id: vehiculeId,
          marque: 'Renault',
          modele: 'Clio',
          prixParJour: 40,
          disponible: false));
      expect(await repo.enregistrer(reservation(DateTime(2026, 12, 1),
          DateTime(2026, 12, 2))), isNotNull);

      await repo.supprimerLocation(premiere.id!);
      expect(await repo.locationsDe(client), hasLength(1));
    });
  });

  group('Hébergement (CRUD et règles)', () {
    test('Prix = prix par nuit x nuits ; supprimer l\'établissement retire ses séjours',
        () async {
      final client = await creerUtilisateur('oussema@test.tn', Role.traveller);
      final voyage = await creerVoyage(client);
      final repo = HebergementRepository();
      final hebergementId = await repo.creerHebergement(const Hebergement(
          nom: 'Hôtel Djerba',
          type: 'Hôtel',
          adresse: 'Houmt Souk',
          prixParNuit: 90));

      final erreur = await repo.enregistrerSejour(ReservationHebergement(
        dateArrivee: DateTime(2026, 11, 10),
        dateDepart: DateTime(2026, 11, 14),
        nbPersonnes: 2,
        voyageId: voyage,
        hebergementId: hebergementId,
      ));
      expect(erreur, isNull);

      final sejours = await repo.sejoursDe(client);
      expect(sejours.single.prixTotal, 360.0);
      expect(sejours.single.nomHebergement, 'Hôtel Djerba');

      await repo.supprimerHebergement(hebergementId);
      expect(await repo.sejoursDe(client), isEmpty);
    });
  });

  group('Forum (sujets, réponses, avis)', () {
    test('Seul l\'auteur modifie ou supprime ses messages et avis', () async {
      final a = await creerUtilisateur('sirine@test.tn', Role.client);
      final b = await creerUtilisateur('amine@test.tn', Role.traveller);
      final repo = ForumRepository();

      final sujetId = await repo.creerSujet(SujetForum(
        titre: 'Bon transporteur ?',
        contenu: 'Quelqu\'un connaît un bus Tunis-Sfax fiable ?',
        creeLe: DateTime.now(),
        auteurId: a,
      ));
      await repo.ajouterReponse(sujetId: sujetId, auteurId: b, contenu: 'Oui, Sahel Bus.');
      final sujet = await repo.sujet(sujetId);
      expect(sujet!.nbReponses, 1);
      expect(sujet.nomAuteur, isNotNull);

      final modifie = SujetForum(
        id: sujetId,
        titre: 'Modifié',
        contenu: 'Texte modifié par un autre membre',
        creeLe: sujet.creeLe,
        auteurId: b,
      );
      expect(await repo.modifierSujet(modifie, b), isFalse);
      expect(await repo.supprimerSujet(sujetId, b), isFalse);

      // Avis sur un hébergement
      final hebergementId = await HebergementRepository().creerHebergement(
          const Hebergement(nom: 'Auberge Sidi', type: 'Auberge', adresse: 'Sidi Bou Saïd', prixParNuit: 45));
      final cibles = await repo.cibles(CibleAvis.hebergement);
      expect(cibles.single.$1, hebergementId);

      final avisId = await repo.creerAvis(Avis(
        cible: CibleAvis.hebergement,
        cibleId: hebergementId,
        note: 4,
        creeLe: DateTime.now(),
        auteurId: a,
        commentaire: 'Propre',
      ));
      final avis = await repo.avis();
      expect(avis.single.libelleCible, 'Auberge Sidi');
      expect(await repo.supprimerAvis(avisId, b), isFalse);
      expect(await repo.supprimerAvis(avisId, a), isTrue);

      expect(await repo.supprimerSujet(sujetId, a), isTrue);
      expect(await repo.reponses(sujetId), isEmpty);
    });
  });

  group('Administration', () {
    test('Actualités : publier, modifier, supprimer', () async {
      final admin = await idDe('admin@travel.tn');
      final repo = AdminRepository();
      final avant = (await repo.actualites()).length;

      await repo.publier(titre: 'Nouvelle offre', contenu: 'Location à prix réduit', auteurId: admin);
      var liste = await repo.actualites();
      expect(liste.length, avant + 1);
      final nouvelle = liste.first;
      expect(nouvelle.titre, 'Nouvelle offre');

      await repo.modifierActualite(nouvelle.id!, titre: 'Offre modifiée', contenu: 'Texte à jour');
      expect((await repo.actualites()).first.titre, 'Offre modifiée');

      await repo.supprimerActualite(nouvelle.id!);
      expect((await repo.actualites()).length, avant);
    });

    test('Comptes : un client peut être supprimé, l\'administrateur jamais', () async {
      final admin = await idDe('admin@travel.tn');
      final client = await creerUtilisateur('supprime@test.tn', Role.client);
      final repo = AdminRepository();

      expect(await repo.supprimerUtilisateur(admin, admin), isNotNull);
      expect(await repo.supprimerUtilisateur(admin, client), isNotNull);
      expect(await repo.supprimerUtilisateur(client, admin), isNull);

      final restants = await repo.utilisateurs();
      expect(restants.any((u) => u.id == client), isFalse);
      expect(restants.any((u) => u.id == admin), isTrue);
    });
  });
}
