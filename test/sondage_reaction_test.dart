import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/user/admin_repository.dart';
import 'package:projet_mobile/modules/user/reaction_repository.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/sondage_repository.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sondages et J'aime du fil d'actualité sur la vraie base SQLite.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
  });

  Future<int> inscrire(String email) async {
    await UserRepository().inscrire(
      nom: 'Test',
      prenom: 'Actu',
      email: email,
      telephone: '20123456',
      motDePasse: 'abcd1234',
      role: Role.client,
    );
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('utilisateur',
        columns: ['id'], where: 'email = ?', whereArgs: [email], limit: 1);
    return rows.first['id'] as int;
  }

  test('sondage : un vote par utilisateur, changer d avis remplace', () async {
    final auteur = await inscrire('auteur@test.tn');
    final autre = await inscrire('autre@test.tn');
    await AdminRepository().publier(
      titre: 'Quel voyage ?',
      contenu: 'Votez pour votre prochaine destination.',
      auteurId: auteur,
    );
    final actu = (await UserRepository().actualites()).firstWhere((a) => a.titre == 'Quel voyage ?');

    final repo = SondageRepository();
    await repo.creerOptions(actu.id!, ['Djerba', 'Tozeur']);
    final options = await repo.optionsPour(actu.id!);
    expect(options.length, 2);

    await repo.voter(actualiteId: actu.id!, optionId: options[0].id!, utilisateurId: auteur);
    // Même utilisateur, autre choix : remplace.
    await repo.voter(actualiteId: actu.id!, optionId: options[1].id!, utilisateurId: auteur);
    // Deuxième utilisateur.
    await repo.voter(actualiteId: actu.id!, optionId: options[0].id!, utilisateurId: autre);

    final resultats = await repo.resultats(actu.id!, utilisateurId: auteur);
    expect(resultats.fold<int>(0, (s, r) => s + r.votes), 2);
    expect(resultats.firstWhere((r) => r.option.libelle == 'Tozeur').choisi, isTrue);
    expect(resultats.firstWhere((r) => r.option.libelle == 'Tozeur').pourcentage, 50.0);
  });

  test('reaction : choix emoji, changement et retrait (comme SyrWriteHub)', () async {
    final auteur = await inscrire('auteur2@test.tn');
    final autre = await inscrire('autre2@test.tn');
    await AdminRepository().publier(
      titre: 'Actualité aimée',
      contenu: 'Contenu assez long pour passer.',
      auteurId: auteur,
    );
    final actu = (await UserRepository().actualites()).firstWhere((a) => a.titre == 'Actualité aimée');

    final repo = ReactionRepository();
    expect(await repo.choisir(actu.id!, auteur, ReactionTypes.like), 'like');
    expect(await repo.choisir(actu.id!, autre, ReactionTypes.love), 'love');
    expect(await repo.compter(actu.id!), 2);
    // Changer de type : total inchangé.
    expect(await repo.choisir(actu.id!, auteur, ReactionTypes.wow), 'wow');
    expect(await repo.compter(actu.id!), 2);
    expect(await repo.maReaction(actu.id!, auteur), 'wow');
    expect(await repo.comptesParType(actu.id!), {'wow': 1, 'love': 1});
    // Même type : retire.
    expect(await repo.choisir(actu.id!, auteur, ReactionTypes.wow), isNull);
    expect(await repo.compter(actu.id!), 1);
  });
}
