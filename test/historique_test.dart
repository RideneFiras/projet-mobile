import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/user/admin_repository.dart';
import 'package:projet_mobile/modules/user/historique_repository.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Historique des posts : modifications et suppressions archivées,
/// conservées même après la suppression du post.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
  });

  test('historique : modification archivée, suppression conservée', () async {
    await UserRepository().inscrire(
      nom: 'Hist',
      prenom: 'Test',
      email: 'hist@test.tn',
      telephone: '20123456',
      motDePasse: 'abcd1234',
      role: Role.client,
    );
    final db = await DatabaseHelper.instance.database;
    final lignes = await db.query('utilisateur',
        columns: ['id'], where: 'email = ?', whereArgs: ['hist@test.tn'], limit: 1);
    final auteur = lignes.first['id'] as int;

    final repo = AdminRepository();
    await repo.publier(
      titre: 'Version un',
      contenu: 'Contenu original assez long.',
      auteurId: auteur,
    );
    final post = (await UserRepository().actualites())
        .firstWhere((a) => a.titre == 'Version un');

    // Dès la création, la première version est dans le stockage.
    final histo = HistoriqueRepository();
    var versions = await histo.versions(post.id!, auteur);
    expect(versions.length, 1);
    expect(versions.first.action, 'creation');

    // Modification : la version précédente est archivée.
    await repo.modifierActualite(post.id!,
        titre: 'Version deux', contenu: 'Contenu modifié assez long.');
    versions = await histo.versions(post.id!, auteur);
    expect(versions.length, 2);
    expect(versions.first.action, 'modification');
    expect(versions.first.titre, 'Version un');

    // Suppression : le post disparaît, l'historique survit.
    await repo.supprimerActualite(post.id!);
    expect((await UserRepository().actualites()).where((a) => a.id == post.id), isEmpty);
    versions = await histo.tout(auteur);
    expect(versions.length, 3);
    expect(versions.first.action, 'suppression');
    expect(versions.first.titre, 'Version deux');
  });
}
