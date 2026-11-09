import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/transporteur/models/commande_transport.dart';
import 'package:projet_mobile/modules/transporteur/models/reservation_transport.dart';
import 'package:projet_mobile/modules/transporteur/models/transporteur.dart';
import 'package:projet_mobile/modules/transporteur/models/voyageur_candidat.dart';
import 'package:projet_mobile/modules/transporteur/transport_format.dart';
import 'package:projet_mobile/modules/transporteur/transport_ia.dart';
import 'package:projet_mobile/modules/transporteur/transport_repository.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests du module transporteur sur la vraie base SQLite (sans émulateur) : flutter test
void main() {
  final repo = TransportRepository();

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
    final comptes = UserRepository();
    await comptes.inscrire(
        nom: 'Ben Salah', prenom: 'Sarra', email: 'sarra@exemple.com',
        telephone: '+216 20 123 456', motDePasse: 'voyage2026', role: Role.client);
    await comptes.inscrire(
        nom: 'Trabelsi', prenom: 'Amine', email: 'amine@exemple.com',
        telephone: '+216 55 000 111', motDePasse: 'voyage2026', role: Role.transporter);
    await comptes.inscrire(
        nom: 'Mansour', prenom: 'Karim', email: 'karim@exemple.com',
        telephone: '+216 98 765 432', motDePasse: 'voyage2026', role: Role.traveller);
    final db = await DatabaseHelper.instance.database;
    await db.insert('voyage', {
      'titre': 'Visite Sfax',
      'destination': 'Sfax',
      'date_debut': '2026-11-15',
      'date_fin': '2026-11-25',
      'budget': 300,
      'statut': 'planifie',
      'utilisateur_id': await idDe('karim@exemple.com'),
    });
  });

  group('Règles de saisie', () {
    test('Prix en centimes sans erreur d\'arrondi', () {
      expect(TransportFormat.parserMontant('12,5'), 1250);
      expect(TransportFormat.parserMontant('12.50'), 1250);
      expect(TransportFormat.parserMontant('0.1') , 10);
      expect(TransportFormat.parserMontant('12.345'), isNull);
      expect(TransportFormat.validerMontant('-3'), isNotNull);
    });

    test('Départ et arrivée doivent être différents', () {
      expect(TransportFormat.validerTrajet('Tunis', 'tunis'), isNotNull);
      expect(TransportFormat.validerTrajet('Tunis', 'Sfax'), isNull);
    });
  });

  group('Trajets et transporteurs (CRUD)', () {
    test('Création, recherche insensible à la casse, suppression', () async {
      final fiche = await repo.creerTransporteur(const Transporteur(
          nom: 'Sahel Bus', type: 'Bus', contact: '+216 73 000 000'));
      final trajetId = await repo.creerTrajet(ReservationTransport(
          depart: 'Tunis',
          arrivee: 'Sfax',
          dateDepart: DateTime(2026, 11, 5),
          prix: 25.5,
          transporteurId: fiche));

      expect(await repo.trajets(depart: 'tunis'), hasLength(1));
      expect(await repo.trajets(date: DateTime(2026, 11, 6)), isEmpty);
      expect((await repo.trajets()).single.nomTransporteur, 'Sahel Bus');

      await repo.supprimerTrajet(trajetId);
      expect(await repo.trajets(), isEmpty);
    });

    test('La base refuse un trajet dont le départ est l\'arrivée', () async {
      await expectLater(
        repo.creerTrajet(ReservationTransport(
            depart: 'Tunis',
            arrivee: 'Tunis',
            dateDepart: DateTime(2026, 11, 5),
            prix: 10)),
        throwsA(anything),
      );
    });

    test('Supprimer une fiche garde ses trajets', () async {
      final fiche = await repo.creerTransporteur(const Transporteur(
          nom: 'Rapide', type: 'Train', contact: '+216 71 111 111'));
      await repo.creerTrajet(ReservationTransport(
          depart: 'Tunis',
          arrivee: 'Gabes',
          dateDepart: DateTime(2026, 12, 1),
          prix: 30,
          transporteurId: fiche));
      await repo.supprimerTransporteur(fiche);
      final restant = await repo.trajets();
      expect(restant, hasLength(1));
      expect(restant.single.transporteurId, isNull);
    });
  });

  group('Commandes et mises en relation', () {
    test('Coordonnées masquées, puis visibles après acceptation', () async {
      final client = await idDe('sarra@exemple.com');
      final transporteur = await idDe('amine@exemple.com');
      final voyageur = await idDe('karim@exemple.com');

      final commandeId = await repo.creerCommande(CommandeTransport(
          clientId: client,
          depart: 'Tunis',
          arrivee: 'Sfax',
          dateSouhaitee: DateTime(2026, 11, 20),
          budget: 50,
          description: 'Colis fragile',
          creeLe: DateTime.now()));

      final ouverte = (await repo.commandesOuvertes()).single;
      expect(ouverte.contactClient, isNull);

      expect(
          await repo.proposerVoyageur(
              commandeId: commandeId,
              auteurId: transporteur,
              voyageurId: voyageur),
          isNull);
      expect(
          await repo.proposerVoyageur(
              commandeId: commandeId,
              auteurId: transporteur,
              voyageurId: voyageur),
          isNotNull);

      final proposition = (await repo.relationsDuVoyageur(voyageur)).single;
      expect(proposition.contactClient, isNull);

      expect(
          await repo.repondreProposition(
              relationId: proposition.id!, voyageurId: voyageur, accepter: true),
          isNull);

      final commande = (await repo.commandesDuClient(client)).single;
      expect(commande.statut, StatutCommande.acceptee);
      expect(commande.voyageurId, voyageur);
      expect(commande.contactVoyageur, isNotNull);
      expect((await repo.relationsDuVoyageur(voyageur)).single.contactClient,
          isNotNull);
      expect(await repo.commandesOuvertes(), isEmpty);
    });

    test('Seul le client peut modifier, annuler ou supprimer sa commande', () async {
      final client = await idDe('sarra@exemple.com');
      final autre = await idDe('karim@exemple.com');
      final id = await repo.creerCommande(CommandeTransport(
          clientId: client,
          depart: 'Tunis',
          arrivee: 'Sfax',
          dateSouhaitee: DateTime(2026, 11, 20),
          budget: 10,
          creeLe: DateTime.now()));
      final commande = (await repo.commandesDuClient(client)).single;

      expect(await repo.annulerCommande(id, autre), isFalse);
      expect(await repo.modifierCommande(commande, autre), isFalse);
      expect(await repo.annulerCommande(id, client), isTrue);
      expect(await repo.annulerCommande(id, client), isFalse);
      expect(await repo.supprimerCommande(id, client), isTrue);
      expect(await repo.commandesDuClient(client), isEmpty);
    });

    test('Une commande acceptée ne peut plus être supprimée', () async {
      final client = await idDe('sarra@exemple.com');
      final transporteur = await idDe('amine@exemple.com');
      final voyageur = await idDe('karim@exemple.com');
      final id = await repo.creerCommande(CommandeTransport(
          clientId: client,
          depart: 'Tunis',
          arrivee: 'Sfax',
          dateSouhaitee: DateTime(2026, 11, 20),
          budget: 10,
          creeLe: DateTime.now()));
      await repo.proposerVoyageur(
          commandeId: id, auteurId: transporteur, voyageurId: voyageur);
      final relation = (await repo.relationsDuVoyageur(voyageur)).single;
      await repo.repondreProposition(
          relationId: relation.id!, voyageurId: voyageur, accepter: true);
      expect(await repo.supprimerCommande(id, client), isFalse);
    });
  });

  group('Assistant IA (repli local)', () {
    test('Lit une phrase : trajet, date relative, budget', () {
      final r = TransportIa.interpreterLocal(
          'De Tunis à Sfax demain, budget 50 DT',
          maintenant: DateTime(2026, 10, 28));
      expect(r.depart, 'Tunis');
      expect(r.arrivee, 'Sfax');
      expect(r.date, DateTime(2026, 10, 29));
      expect(r.budget, 50.0);
      expect(r.source, SourceIa.local);
    });

    test('Classe d\'abord le voyageur qui va à la bonne destination', () {
      final candidats = [
        VoyageurCandidat(id: 1, nom: 'Karim', voyages: [
          VoyageTrajet(
              destination: 'Sfax',
              dateDebut: DateTime(2026, 11, 15),
              dateFin: DateTime(2026, 11, 25)),
        ]),
        VoyageurCandidat(id: 2, nom: 'Sarra', voyages: [
          VoyageTrajet(
              destination: 'Gabes',
              dateDebut: DateTime(2026, 12, 1),
              dateFin: DateTime(2026, 12, 5)),
        ]),
      ];
      final commande = CommandeTransport(
          clientId: 9,
          depart: 'Tunis',
          arrivee: 'Sfax',
          dateSouhaitee: DateTime(2026, 11, 18),
          budget: 40,
          creeLe: DateTime(2026, 10, 28));
      final scores = TransportIa.classerLocal(commande, candidats);
      expect(scores.first.voyageur.id, 1);
      expect(scores.first.score, greaterThan(scores.last.score));
    });
  });
}
