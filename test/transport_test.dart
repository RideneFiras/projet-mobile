import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/transporteur/models/commande_transport.dart';
import 'package:projet_mobile/modules/transporteur/models/mise_en_relation.dart';
import 'package:projet_mobile/modules/transporteur/models/reservation_transport.dart';
import 'package:projet_mobile/modules/transporteur/models/trajet_transport.dart';
import 'package:projet_mobile/modules/transporteur/models/transporteur.dart';
import 'package:projet_mobile/modules/transporteur/transport_format.dart';
import 'package:projet_mobile/modules/transporteur/transport_repository.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests du module transporteur sur la vraie base SQLite (sans émulateur) : flutter test
void main() {
  final repo = TransportRepository();
  final jour = DateTime(2030, 11, 15, 9);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<int> idDe(String email) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('utilisateur',
        columns: ['id'], where: 'email = ?', whereArgs: [email], limit: 1);
    return rows.first['id'] as int;
  }

  Future<void> profilDe(String email, String nom, String ville) async {
    final erreur = await repo.creerProfil(Transporteur(
      utilisateurId: await idDe(email),
      nom: nom,
      telephone: '+216 55 000 111',
      email: email,
      ville: ville,
      typeTransport: 'collectif',
      capacite: 8,
      creeLe: DateTime.now(),
    ));
    expect(erreur, isNull);
  }

  /// Crée un trajet pour le transporteur [email] et renvoie son id.
  Future<int> trajetPour(
    String email, {
    String depart = 'Tunis',
    String arrivee = 'Sfax',
    DateTime? date,
    int places = 4,
    double prix = 20,
  }) async {
    final uid = await idDe(email);
    final profil = (await repo.profilDe(uid))!;
    final debut = date ?? jour;
    final erreur = await repo.creerTrajet(
        TrajetTransport(
          transporteurId: profil.id!,
          villeDepart: depart,
          destination: arrivee,
          dateDepart: debut,
          dateArriveeEstimee: debut.add(const Duration(hours: 2)),
          prixParPersonne: prix,
          placesTotales: places,
          typeTransport: 'collectif',
          creeLe: DateTime.now(),
        ),
        uid);
    expect(erreur, isNull);
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('SELECT MAX(id) AS id FROM trajet_transport');
    return rows.first['id'] as int;
  }

  /// Crée une demande du voyageur [email] et renvoie son id.
  Future<int> commandePour(
    String email, {
    String depart = 'Tunis',
    String arrivee = 'Sfax',
    DateTime? date,
    int passagers = 1,
    double budget = 0,
  }) async {
    final resultat = await repo.creerCommande(CommandeTransport(
      voyageurId: await idDe(email),
      depart: depart,
      arrivee: arrivee,
      dateVoyage: date ?? jour,
      nombrePassagers: passagers,
      prixPropose: budget,
      creeLe: DateTime.now(),
    ));
    return resultat.id;
  }

  /// Proposition reçue par [email] pour la commande [commandeId].
  Future<MiseEnRelation> relationDe(String email, int commandeId) async {
    final relations = await repo.relationsDuTransporteur(await idDe(email));
    return relations.firstWhere((r) => r.commandeId == commandeId);
  }

  /// Accepte, pour le transporteur [email], la proposition de la commande [commandeId].
  Future<String?> accepter(String email, int commandeId) async {
    final relation = await relationDe(email, commandeId);
    return repo.repondreProposition(
      relationId: relation.id!,
      utilisateurId: await idDe(email),
      accepter: true,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
    final comptes = UserRepository();
    await comptes.inscrire(
        nom: 'Ben Salah', prenom: 'Sarra', email: 'sarra@exemple.com',
        telephone: '+216 20 123 456', motDePasse: 'voyage2026', role: Role.traveller);
    await comptes.inscrire(
        nom: 'Mansour', prenom: 'Karim', email: 'karim@exemple.com',
        telephone: '+216 98 765 432', motDePasse: 'voyage2026', role: Role.traveller);
    await comptes.inscrire(
        nom: 'Trabelsi', prenom: 'Amine', email: 'amine@exemple.com',
        telephone: '+216 55 000 111', motDePasse: 'voyage2026', role: Role.transporter);
    await comptes.inscrire(
        nom: 'Hamdi', prenom: 'Sana', email: 'sana@exemple.com',
        telephone: '+216 22 333 444', motDePasse: 'voyage2026', role: Role.transporter);
    await profilDe('amine@exemple.com', 'Trabelsi Transport', 'Tunis');
    await profilDe('sana@exemple.com', 'Sana Navette', 'Sousse');
  });

  group('Règles de saisie', () {
    test("Prix en centimes, sans erreur d'arrondi", () {
      expect(TransportFormat.parserMontant('12,5'), 1250);
      expect(TransportFormat.parserMontant('12.50'), 1250);
      expect(TransportFormat.parserMontant('0.1'), 10);
      expect(TransportFormat.parserMontant('12.345'), isNull);
      expect(TransportFormat.validerMontant('-3'), isNotNull);
    });

    test('Heure au format HH:mm', () {
      expect(TransportFormat.parserHeure('9:05'), (9, 5));
      expect(TransportFormat.parserHeure('24:00'), isNull);
    });

    test("Le départ et l'arrivée doivent être différents", () {
      expect(TransportFormat.validerTrajet('Tunis', 'tunis'), isNotNull);
      expect(TransportFormat.validerTrajet('Tunis', 'Sfax'), isNull);
    });
  });

  group('Profil transporteur', () {
    test('Un seul profil par compte', () async {
      final erreur = await repo.creerProfil(Transporteur(
        utilisateurId: await idDe('amine@exemple.com'),
        nom: 'Doublon',
        telephone: '+216 1',
        email: 'amine@exemple.com',
        ville: 'Tunis',
        typeTransport: 'individuel',
        creeLe: DateTime.now(),
      ));
      expect(erreur, isNotNull);
    });

    test('Désactivé, le profil disparaît des recherches sans être supprimé', () async {
      final uid = await idDe('amine@exemple.com');
      await trajetPour('amine@exemple.com');
      expect((await repo.rechercherTrajets(depart: 'Tunis')).trajets, hasLength(1));

      await repo.changerActivite(uid, actif: false);
      expect((await repo.rechercherTrajets(depart: 'Tunis')).trajets, isEmpty);
      expect(await repo.profilDe(uid), isNotNull);
    });
  });

  group('Recherche, tri et pagination', () {
    test('Pagination : 10 résultats par page, total et page suivante', () async {
      for (var i = 0; i < 12; i++) {
        await trajetPour('amine@exemple.com',
            date: jour.add(Duration(days: i)), prix: 50 - i.toDouble());
      }
      final p1 = await repo.rechercherTrajets(depart: 'Tunis', arrivee: 'Sfax');
      expect(p1.total, 12);
      expect(p1.nombrePages, 2);
      expect(p1.trajets, hasLength(10));
      expect(p1.aSuivante, isTrue);
      expect(p1.aPrecedente, isFalse);

      final p2 = await repo.rechercherTrajets(depart: 'Tunis', arrivee: 'Sfax', page: 2);
      expect(p2.trajets, hasLength(2));
      expect(p2.aSuivante, isFalse);
      expect(p2.aPrecedente, isTrue);
    });

    test('Tri par prix croissant, puis par places libres', () async {
      await trajetPour('amine@exemple.com', date: jour, prix: 30, places: 2);
      await trajetPour('amine@exemple.com',
          date: jour.add(const Duration(days: 1)), prix: 10, places: 6);
      await trajetPour('amine@exemple.com',
          date: jour.add(const Duration(days: 2)), prix: 20, places: 4);

      final parPrix =
          await repo.rechercherTrajets(depart: 'Tunis', tri: TriTrajet.prixCroissant);
      expect(parPrix.trajets.map((t) => t.prixParPersonne).toList(), [10, 20, 30]);

      final parPlaces =
          await repo.rechercherTrajets(depart: 'Tunis', tri: TriTrajet.placesLibres);
      expect(parPlaces.trajets.first.placesTotales, 6);
    });

    test("Un trajet passé n'apparaît plus dans la recherche", () async {
      final id = await trajetPour('amine@exemple.com');
      final db = await DatabaseHelper.instance.database;
      await db.update('trajet_transport', {'date_depart': '2020-01-01T09:00:00.000'},
          where: 'id = ?', whereArgs: [id]);
      expect((await repo.rechercherTrajets(depart: 'Tunis')).total, 0);
    });

    test('Page demandée hors limites : renvoie la dernière page', () async {
      await trajetPour('amine@exemple.com');
      final p = await repo.rechercherTrajets(depart: 'Tunis', page: 9);
      expect(p.page, 1);
      expect(p.trajets, hasLength(1));
    });
  });

  group('Trajets annulés', () {
    test('Annuler le trajet refuse les propositions en attente et refuse la commande', () async {
      final uid = await idDe('amine@exemple.com');
      final trajet = await trajetPour('amine@exemple.com');
      final commande = await commandePour('sarra@exemple.com');
      expect(await repo.changerStatutTrajet(trajet, uid, StatutTrajet.annule), isNull);

      final relation = await relationDe('amine@exemple.com', commande);
      expect(relation.enAttente, isFalse);
      final c = (await repo.commandesDuVoyageur(await idDe('sarra@exemple.com'))).single;
      expect(c.statut, StatutCommande.refusee);
    });

    test('Accepter une proposition sur un trajet annulé est refusé', () async {
      final uid = await idDe('amine@exemple.com');
      final trajet = await trajetPour('amine@exemple.com');
      final commande = await commandePour('sarra@exemple.com');
      final relation = await relationDe('amine@exemple.com', commande);

      // Trajet annulé directement en base : la proposition reste « proposee ».
      final db = await DatabaseHelper.instance.database;
      await db.update('trajet_transport', {'statut': 'annule'},
          where: 'id = ?', whereArgs: [trajet]);

      expect(
        await repo.repondreProposition(
            relationId: relation.id!, utilisateurId: uid, accepter: true),
        "Ce trajet n'est plus disponible",
      );
      final reservations = await db.rawQuery('SELECT COUNT(*) AS n FROM reservation_transport');
      expect(reservations.first['n'], 0);
    });
  });

  group('Trajets', () {
    test('Recherche insensible à la casse, filtrée par date', () async {
      await trajetPour('amine@exemple.com');
      expect((await repo.rechercherTrajets(depart: 'tunis')).trajets, hasLength(1));
      expect((await repo.rechercherTrajets(jour: jour)).trajets, hasLength(1));
      expect((await repo.rechercherTrajets(jour: DateTime(2030, 11, 16))).trajets, isEmpty);
    });

    test('Duplication à une autre date, même heure et même durée', () async {
      final id = await trajetPour('amine@exemple.com');
      final uid = await idDe('amine@exemple.com');
      expect(await repo.dupliquerTrajet(id, uid, DateTime(2030, 12, 20)), isNull);

      final copie = (await repo.trajetsDuTransporteur(uid))
          .firstWhere((t) => t.dateDepart.month == 12);
      expect(copie.dateDepart, DateTime(2030, 12, 20, 9));
      expect(copie.dateArriveeEstimee, DateTime(2030, 12, 20, 11));
      expect(copie.statut, StatutTrajet.planifie);
    });

    test('Statuts : planifié → en cours → terminé, sans retour en arrière', () async {
      final id = await trajetPour('amine@exemple.com');
      final uid = await idDe('amine@exemple.com');
      expect(await repo.changerStatutTrajet(id, uid, StatutTrajet.termine), isNotNull);
      expect(await repo.changerStatutTrajet(id, uid, StatutTrajet.enCours), isNull);
      expect(await repo.changerStatutTrajet(id, uid, StatutTrajet.termine), isNull);
      expect(await repo.changerStatutTrajet(id, uid, StatutTrajet.planifie), isNotNull);
    });

    test("Un transporteur ne touche pas au trajet d'un autre", () async {
      final id = await trajetPour('amine@exemple.com');
      final autre = await idDe('sana@exemple.com');
      expect(await repo.changerStatutTrajet(id, autre, StatutTrajet.enCours), isNotNull);
      expect(await repo.supprimerTrajet(id, autre), isNotNull);
    });

    test('Modifier un trajet ne descend pas sous les places réservées', () async {
      await trajetPour('amine@exemple.com', places: 4);
      final uid = await idDe('amine@exemple.com');
      final id = await commandePour('karim@exemple.com', passagers: 3);
      expect(await accepter('amine@exemple.com', id), isNull);

      final trajet = (await repo.trajetsDuTransporteur(uid)).single;
      final reduit = TrajetTransport(
        id: trajet.id,
        transporteurId: trajet.transporteurId,
        villeDepart: trajet.villeDepart,
        destination: trajet.destination,
        dateDepart: trajet.dateDepart,
        dateArriveeEstimee: trajet.dateArriveeEstimee,
        prixParPersonne: trajet.prixParPersonne,
        placesTotales: 2,
        typeTransport: trajet.typeTransport,
        creeLe: trajet.creeLe,
      );
      expect(await repo.modifierTrajet(reduit, uid), isNotNull);
    });
  });

  group('Mise en relation automatique', () {
    test('Une demande est proposée seulement aux trajets compatibles', () async {
      await trajetPour('amine@exemple.com', places: 4, prix: 20); // compatible
      await trajetPour('sana@exemple.com', arrivee: 'Gabes'); // autre destination
      await trajetPour('sana@exemple.com', date: jour.add(const Duration(days: 1))); // autre jour
      await trajetPour('sana@exemple.com', places: 1); // pas assez de places
      await trajetPour('sana@exemple.com', prix: 50); // au-dessus du budget

      final demande = await repo.creerCommande(CommandeTransport(
        voyageurId: await idDe('karim@exemple.com'),
        depart: 'Tunis',
        arrivee: 'Sfax',
        dateVoyage: jour,
        nombrePassagers: 2,
        prixPropose: 50,
        creeLe: DateTime.now(),
      ));
      expect(demande.propositions, 1);
      expect(await repo.relationsDuTransporteur(await idDe('amine@exemple.com')),
          hasLength(1));
      expect(await repo.relationsDuTransporteur(await idDe('sana@exemple.com')), isEmpty);
    });

    test('Accepter crée la réservation, refuse les autres propositions, révèle le contact',
        () async {
      await trajetPour('amine@exemple.com');
      await trajetPour('sana@exemple.com');
      final id = await commandePour('karim@exemple.com', passagers: 2);
      expect((await relationDe('amine@exemple.com', id)).telephoneVoyageur, isEmpty);

      expect(await accepter('amine@exemple.com', id), isNull);

      final commande =
          (await repo.commandesDuVoyageur(await idDe('karim@exemple.com'))).single;
      expect(commande.statut, StatutCommande.acceptee);
      expect(commande.nomTransporteur, 'Trabelsi Transport');

      expect((await relationDe('sana@exemple.com', id)).statut, StatutRelation.refusee);

      final amine = await idDe('amine@exemple.com');
      final reservations = await repo.reservationsDuTransporteur(amine);
      expect(reservations.single.nombrePlaces, 2);
      expect(reservations.single.statut, StatutReservation.confirmee);
      expect((await repo.trajetsDuTransporteur(amine)).single.placesLibres, 2);

      expect((await relationDe('amine@exemple.com', id)).telephoneVoyageur,
          '+216 98 765 432');
    });

    test('Accepter sans assez de places est refusé', () async {
      await trajetPour('amine@exemple.com', places: 3);
      final premiere = await commandePour('karim@exemple.com', passagers: 2);
      final seconde = await commandePour('sarra@exemple.com', passagers: 2);

      expect(await accepter('amine@exemple.com', premiere), isNull);
      expect(await accepter('amine@exemple.com', seconde), isNotNull);
    });

    test('Refuser toutes les propositions refuse la commande', () async {
      await trajetPour('amine@exemple.com');
      final id = await commandePour('karim@exemple.com');
      final relation = await relationDe('amine@exemple.com', id);
      expect(
        await repo.repondreProposition(
          relationId: relation.id!,
          utilisateurId: await idDe('amine@exemple.com'),
          accepter: false,
        ),
        isNull,
      );
      final commande =
          (await repo.commandesDuVoyageur(await idDe('karim@exemple.com'))).single;
      expect(commande.statut, StatutCommande.refusee);
    });

    test('Une proposition ne se traite que par son transporteur', () async {
      await trajetPour('amine@exemple.com');
      final id = await commandePour('karim@exemple.com');
      final relation = await relationDe('amine@exemple.com', id);
      expect(
        await repo.repondreProposition(
          relationId: relation.id!,
          utilisateurId: await idDe('sana@exemple.com'),
          accepter: true,
        ),
        isNotNull,
      );
    });

    test('Un trajet publié après la demande lui est proposé', () async {
      final demande = await repo.creerCommande(CommandeTransport(
        voyageurId: await idDe('karim@exemple.com'),
        depart: 'Tunis',
        arrivee: 'Sfax',
        dateVoyage: jour,
        nombrePassagers: 2,
        prixPropose: 0,
        creeLe: DateTime.now(),
      ));
      expect(demande.propositions, 0);

      await trajetPour('amine@exemple.com', places: 4, prix: 20);
      final proposees = await repo.relationsDuTransporteur(
          await idDe('amine@exemple.com'),
          statut: StatutRelation.proposee);
      expect(proposees, hasLength(1));
    });

    test('Un transporteur indisponible ne reçoit aucune nouvelle demande', () async {
      await trajetPour('amine@exemple.com', prix: 20);
      final db = await DatabaseHelper.instance.database;
      await db.update('transporteur', {'disponible': 0},
          where: 'utilisateur_id = ?', whereArgs: [await idDe('amine@exemple.com')]);
      final demande = await repo.creerCommande(CommandeTransport(
        voyageurId: await idDe('karim@exemple.com'),
        depart: 'Tunis',
        arrivee: 'Sfax',
        dateVoyage: jour,
        nombrePassagers: 1,
        prixPropose: 0,
        creeLe: DateTime.now(),
      ));
      expect(demande.propositions, 0);
    });

    test('Les villes sont comparées sans tenir compte des accents ni de la casse', () async {
      await trajetPour('amine@exemple.com', arrivee: 'Médenine', prix: 20);
      final demande = await repo.creerCommande(CommandeTransport(
        voyageurId: await idDe('karim@exemple.com'),
        depart: 'tunis',
        arrivee: 'Medenine',
        dateVoyage: jour,
        nombrePassagers: 1,
        prixPropose: 0,
        creeLe: DateTime.now(),
      ));
      expect(demande.propositions, 1);
    });

    test('Un refus laisse la demande dans les annulées, sans créer de réservation', () async {
      await trajetPour('amine@exemple.com', prix: 20);
      final commande = await commandePour('karim@exemple.com');
      final relation = await relationDe('amine@exemple.com', commande);
      final erreur = await repo.repondreProposition(
        relationId: relation.id!,
        utilisateurId: await idDe('amine@exemple.com'),
        accepter: false,
      );
      expect(erreur, isNull);
      final annulees = await repo.relationsDuTransporteur(
          await idDe('amine@exemple.com'),
          statut: StatutRelation.refusee);
      expect(annulees, hasLength(1));
      expect(await repo.reservationsDuTransporteur(await idDe('amine@exemple.com')),
          isEmpty);
    });
  });

  group('Annulations et prise en charge', () {
    test('Le voyageur annule une demande en attente, sans motif', () async {
      final id = await commandePour('karim@exemple.com');
      final uid = await idDe('karim@exemple.com');
      expect(await repo.annulerCommande(id, await idDe('sarra@exemple.com')), isNotNull);
      expect(await repo.annulerCommande(id, uid), isNull);
      expect((await repo.commandesDuVoyageur(uid)).single.statut, StatutCommande.annulee);
    });

    test('Réservation : le voyageur annule plus de 24 h avant, avec un motif', () async {
      await trajetPour('amine@exemple.com');
      final id = await commandePour('karim@exemple.com', passagers: 2);
      final uid = await idDe('karim@exemple.com');
      expect(await accepter('amine@exemple.com', id), isNull);

      expect(await repo.annulerCommande(id, uid), isNotNull, reason: 'motif obligatoire');
      expect(await repo.annulerCommande(id, uid, motif: 'Changement de plan'), isNull);

      expect((await repo.commandesDuVoyageur(uid)).single.statut, StatutCommande.annulee);
      final reservation = (await repo.reservationsDuVoyageur(uid)).single;
      expect(reservation.statut, StatutReservation.annulee);
      expect(reservation.motifAnnulation, 'Changement de plan');
    });

    test('Pas d\'annulation du voyageur moins de 24 h avant le départ', () async {
      final bientot = DateTime.now().add(const Duration(hours: 2));
      await trajetPour('amine@exemple.com', date: bientot);
      final id = await commandePour('karim@exemple.com', date: bientot);
      expect(await accepter('amine@exemple.com', id), isNull);

      final erreur = await repo.annulerCommande(
        id,
        await idDe('karim@exemple.com'),
        motif: 'Imprévu',
      );
      expect(erreur, contains('24 h'));
    });

    test('Le transporteur annule avec un motif, qui reste dans l\'historique', () async {
      await trajetPour('amine@exemple.com');
      final id = await commandePour('karim@exemple.com');
      final amine = await idDe('amine@exemple.com');
      expect(await accepter('amine@exemple.com', id), isNull);
      final reservation = (await repo.reservationsDuTransporteur(amine)).single;

      expect(
          await repo.annulerReservationParTransporteur(reservation.id!, amine, motif: ' '),
          isNotNull);
      expect(
          await repo.annulerReservationParTransporteur(reservation.id!, amine,
              motif: 'Véhicule en panne'),
          isNull);

      final historique = await repo.historique(reservation.id!);
      expect(historique.map((e) => e.evenement), contains(contains('Véhicule en panne')));
      expect((await repo.commandesDuVoyageur(await idDe('karim@exemple.com'))).single.statut,
          StatutCommande.annulee);
    });

    test('Prise en charge confirmée par le transporteur', () async {
      await trajetPour('amine@exemple.com');
      final id = await commandePour('karim@exemple.com');
      final amine = await idDe('amine@exemple.com');
      expect(await accepter('amine@exemple.com', id), isNull);
      final reservation = (await repo.reservationsDuTransporteur(amine)).single;

      expect(await repo.confirmerPriseEnCharge(reservation.id!, amine), isNull);
      expect((await repo.reservationsDuTransporteur(amine)).single.statut,
          StatutReservation.priseEnCharge);
    });
  });
}
