import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:projet_mobile/modules/user/visage/comparateur_visage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Vérification faciale (2FA) — module user. Les visages sont simulés par des
/// vecteurs de 128 nombres (pas de caméra en test).
void main() {
  final repo = UserRepository();

  // Visage « de référence » et variantes proches / éloignées.
  final moi = List<double>.generate(128, (i) => (i % 7) / 10);
  final moiAutrePhoto = [for (final x in moi) x + 0.02]; // distance ≈ 0.23
  final autrePersonne = [for (final x in moi) x + 0.1]; // distance ≈ 1.13

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
  });

  Future<int> inscrireEtDeconnecter() async {
    await repo.inscrire(
      nom: 'Ben Salah',
      prenom: 'Sarra',
      email: 'sarra@exemple.com',
      telephone: '+216 20 123 456',
      motDePasse: 'voyage2026',
      role: Role.client,
    );
    final id = (await repo.utilisateurConnecte())!.id!;
    await repo.deconnecter();
    return id;
  }

  group('Comparateur de visages', () {
    test('Même personne sous le seuil, autre personne au-dessus', () {
      expect(ComparateurVisage.distance(moi, moi), 0);
      expect(ComparateurVisage.correspond(moi, moiAutrePhoto), isTrue);
      expect(ComparateurVisage.correspond(moi, autrePersonne), isFalse);
    });

    test('Encodage JSON aller-retour et validation de taille', () {
      expect(ComparateurVisage.decoder(ComparateurVisage.encoder(moi)), moi);
      expect(ComparateurVisage.estValide(moi), isTrue);
      expect(ComparateurVisage.estValide([1, 2, 3]), isFalse);
    });
  });

  group('Connexion avec vérification faciale', () {
    test('Sans visage activé : le mot de passe suffit', () async {
      await inscrireEtDeconnecter();
      final r = await repo.connexion('sarra@exemple.com', 'voyage2026');
      expect(r.erreur, isNull);
      expect(r.visageRequisPour, isNull);
      expect(await repo.utilisateurConnecte(), isNotNull);
    });

    test('Visage activé : session ouverte seulement après le bon visage',
        () async {
      final id = await inscrireEtDeconnecter();
      expect(await repo.activerVisage(id, moi), isNull);
      expect(await repo.visageActive(id), isTrue);

      // Étape 1 : bon mot de passe -> visage requis, pas encore de session.
      final r = await repo.connexion('sarra@exemple.com', 'voyage2026');
      expect(r.visageRequisPour, id);
      expect(await repo.utilisateurConnecte(), isNull);
      expect(await repo.connecter('sarra@exemple.com', 'voyage2026'),
          'Vérification faciale requise');

      // Étape 2 : mauvais visage refusé, bon visage accepté.
      expect(await repo.connecterAvecVisage(id, autrePersonne),
          'Visage non reconnu');
      expect(await repo.utilisateurConnecte(), isNull);
      expect(await repo.connecterAvecVisage(id, moiAutrePhoto), isNull);
      expect((await repo.utilisateurConnecte())!.id, id);
    });

    test('Mauvais mot de passe : le visage n\'est jamais demandé', () async {
      final id = await inscrireEtDeconnecter();
      await repo.activerVisage(id, moi);
      final r = await repo.connexion('sarra@exemple.com', 'mauvais1');
      expect(r.erreur, isNotNull);
      expect(r.visageRequisPour, isNull);
    });

    test('Désactivation : retour au mot de passe seul', () async {
      final id = await inscrireEtDeconnecter();
      await repo.activerVisage(id, moi);
      await repo.desactiverVisage(id);
      expect(await repo.visageActive(id), isFalse);
      expect(await repo.connecter('sarra@exemple.com', 'voyage2026'), isNull);
    });
  });
}
