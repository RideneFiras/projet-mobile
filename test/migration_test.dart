import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/user/admin_repository.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Reproduit le cas signalé : posts publiés par un compte, puis
/// ouverture par un AUTRE compte — doivent rester visibles.
/// Et migration d'une ancienne base (sans les nouvelles colonnes).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.reinitialiser();
  });

  Future<int> inscrire(String email, String prenom) async {
    await UserRepository().inscrire(
      nom: 'Test',
      prenom: prenom,
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

  test('post de A reste visible pour B (fil commun, autre compte)', () async {
    final sarra = await inscrire('sarra2@test.tn', 'Sarra');
    await AdminRepository().publier(
      titre: 'Post de Sarra',
      contenu: 'Contenu assez long pour passer.',
      auteurId: sarra,
    );
    // Karim se connecte (autre compte) : il ouvre le fil.
    final karim = await inscrire('karim2@test.tn', 'Karim');
    final fil = await UserRepository().actualites();
    final vu = fil.where((a) => a.titre == 'Post de Sarra');
    expect(vu, isNotEmpty, reason: 'Le post de Sarra doit rester visible pour Karim');
    expect(vu.first.auteurNom, contains('Sarra'));
    // Karim voit aussi les posts admin (graines) : jamais un fil vide.
    expect(fil.length, greaterThanOrEqualTo(3));
  });

  test('migration : ancienne base sans nouvelles colonnes', () async {
    final db = await DatabaseHelper.instance.database;
    // Recrée l'ancienne table (5 colonnes) avec un post dedans.
    await db.execute('DROP TABLE actualite');
    await db.execute('''
      CREATE TABLE actualite (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titre TEXT NOT NULL,
        contenu TEXT NOT NULL,
        date_publication TEXT NOT NULL,
        auteur_id INTEGER
      )
    ''');
    await db.insert('actualite', {
      'titre': 'Ancien post',
      'contenu': 'Écrit avant les nouvelles colonnes.',
      'date_publication': DateTime.now().toUtc().toIso8601String(),
      'auteur_id': null,
    });

    // On rejoue ici les mêmes ALTER que la migration de l'app au démarrage.
    await db.execute("ALTER TABLE actualite ADD COLUMN photo TEXT");
    await db.execute("ALTER TABLE actualite ADD COLUMN epingle INTEGER NOT NULL DEFAULT 0");
    await db.execute("ALTER TABLE actualite ADD COLUMN type_post TEXT NOT NULL DEFAULT 'standard'");
    await db.execute("ALTER TABLE actualite ADD COLUMN date_evenement TEXT");
    await db.execute("ALTER TABLE actualite ADD COLUMN lieu TEXT");
    await db.execute("ALTER TABLE actualite ADD COLUMN audience TEXT NOT NULL DEFAULT 'tous'");
    await db.execute("ALTER TABLE actualite ADD COLUMN categorie TEXT NOT NULL DEFAULT 'general'");

    final fil = await UserRepository().actualites();
    expect(fil.any((a) => a.titre == 'Ancien post'), isTrue);
  });
}
