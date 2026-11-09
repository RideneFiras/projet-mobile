import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/core/services/session_service.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Teste la vraie base SQLite sur le PC (sans émulateur) : flutter test
void main() {
  final repo = UserRepository();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
  });

  Future<String?> inscrireSarra({String email = 'sarra@exemple.com'}) =>
      repo.inscrire(
        nom: 'Ben Salah',
        prenom: 'Sarra',
        email: email,
        telephone: '+216 20 123 456',
        motDePasse: 'voyage2026',
        role: Role.client,
      );

  test('Inscription ouvre la session avec le bon rôle', () async {
    expect(await inscrireSarra(), isNull);
    final u = await repo.utilisateurConnecte();
    expect(u, isNotNull);
    expect(u!.prenom, 'Sarra');
    expect(u.role, Role.client);
    expect(u.initiales, 'SB');
  });

  test('E-mail unique, sans tenir compte des majuscules', () async {
    await inscrireSarra();
    expect(await inscrireSarra(email: 'SARRA@exemple.com'),
        'Cet e-mail est déjà utilisé');
  });

  test('Connexion : mauvais puis bon mot de passe', () async {
    await inscrireSarra();
    await repo.deconnecter();
    expect(await SessionService.instance.utilisateurId(), isNull);
    expect(await repo.connecter('sarra@exemple.com', 'mauvais1'), isNotNull);
    expect(await repo.connecter('Sarra@Exemple.com', 'voyage2026'), isNull);
    expect((await repo.utilisateurConnecte())!.email, 'sarra@exemple.com');
  });

  test("Impossible de s'inscrire comme admin", () async {
    final r = await repo.inscrire(
        nom: 'X', prenom: 'Y', email: 'x@y.tn', telephone: '12345678',
        motDePasse: 'abcd1234', role: Role.admin);
    expect(r, isNotNull);
  });

  test('Profil modifiable, actualités de départ présentes', () async {
    await inscrireSarra();
    final u = (await repo.utilisateurConnecte())!;
    await repo.mettreAJourProfil(u.copyWith(prenom: 'Sara'));
    expect((await repo.utilisateurConnecte())!.prenom, 'Sara');
    expect(await repo.actualites(), hasLength(2));
  });
}
