import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/forum/forum_repository.dart';
import 'package:projet_mobile/modules/forum/models/avis.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Migration v5 : fusion des branches « fil d'actualité », « transporteur » et
/// « location / hébergement ». Une base installée avec l'ancienne branche
/// (version 4, ancien module transporteur, ancien fil) doit s'ouvrir sans perte.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.reinitialiser();
  });

  /// Base « version 4 » telle que l'installait la branche location / hébergement.
  Future<void> creerAncienneBase() async {
    final chemin = join(await getDatabasesPath(), DatabaseHelper.nomBase);
    final ancienne = await openDatabase(chemin, version: 4, onCreate: (db, _) async {
      await db.execute('CREATE TABLE utilisateur (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'nom TEXT NOT NULL, prenom TEXT NOT NULL, email TEXT NOT NULL UNIQUE, '
          'telephone TEXT NOT NULL, role TEXT NOT NULL, mot_de_passe_hash TEXT NOT NULL, '
          'sel TEXT NOT NULL, cree_le TEXT NOT NULL)');
      await db.execute('CREATE TABLE actualite (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'titre TEXT NOT NULL, contenu TEXT NOT NULL, date_publication TEXT NOT NULL, '
          'auteur_id INTEGER)');
      // Ancienne forme du module transporteur (4 tables, sans trajets).
      await db.execute('CREATE TABLE transporteur (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'nom TEXT NOT NULL, type TEXT NOT NULL, contact TEXT NOT NULL)');
      await db.execute('CREATE TABLE avis (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          "cible_type TEXT NOT NULL CHECK (cible_type IN ('location','hebergement','transport')), "
          'cible_id INTEGER NOT NULL, note INTEGER NOT NULL, commentaire TEXT, '
          'cree_le TEXT NOT NULL, auteur_id INTEGER NOT NULL)');
      await db.insert('utilisateur', {
        'nom': 'Test',
        'prenom': 'Ancien',
        'email': 'ancien@test.tn',
        'telephone': '20123456',
        'role': 'client',
        'mot_de_passe_hash': 'h',
        'sel': 's',
        'cree_le': '2026-01-01T00:00:00.000Z',
      });
      await db.insert('actualite', {
        'titre': 'Ancien post',
        'contenu': 'Écrit avant la fusion des branches.',
        'date_publication': '2026-01-01T00:00:00.000Z',
        'auteur_id': 1,
      });
      await db.insert('transporteur', {'nom': 'Bus', 'type': 'bus', 'contact': 'x'});
      for (final type in ['transport', 'location']) {
        await db.insert('avis', {
          'cible_type': type,
          'cible_id': 1,
          'note': 4,
          'commentaire': 'ancien avis',
          'cree_le': '2026-01-02T00:00:00.000Z',
          'auteur_id': 1,
        });
      }
    });
    await ancienne.close();
  }

  test('base v4 -> v5 : données conservées, transporteur et fil mis à niveau', () async {
    await creerAncienneBase();

    final db = await DatabaseHelper.instance.database;
    expect(await db.getVersion(), 5);

    // Fil : l'ancien post reste lisible, avec les valeurs par défaut des nouvelles colonnes.
    final post = (await db.query('actualite')).single;
    expect(post['titre'], 'Ancien post');
    expect(post['type_post'], 'standard');
    expect(post['audience'], 'tous');

    // Transporteur : nouvelle forme (trajets, profil lié au compte), ancienne table supprimée.
    expect(await db.query('trajet_transport'), isEmpty);
    expect(await db.query('historique_reservation'), isEmpty);
    final colonnes = (await db.rawQuery('PRAGMA table_info(transporteur)'))
        .map((c) => c['name'])
        .toList();
    expect(colonnes, contains('utilisateur_id'));

    // Avis : ceux du transport visaient l'ancienne table et sont purgés ; les autres restent.
    final avis = await db.query('avis');
    expect(avis.single['cible_type'], 'location');

    // Clés étrangères réactivées après la migration.
    expect((await db.rawQuery('PRAGMA foreign_keys')).first.values.first, 1);
  });

  test('forum : avis et cibles « transport » lisibles avec le nouveau schéma', () async {
    await creerAncienneBase();
    final repo = ForumRepository();

    expect(await repo.avis(), hasLength(1));
    expect(await repo.cibles(CibleAvis.transport), isEmpty);
  });
}
