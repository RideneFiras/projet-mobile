import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/user/admin_repository.dart';
import 'package:projet_mobile/modules/user/commentaire.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/commentaire_repository.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Commentaires du fil d'actualité sur la vraie base SQLite (sans émulateur).
/// Règle : seul l'auteur modifie ou supprime SON commentaire.
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

  test('commentaires : CRUD réservé à son auteur', () async {
    final sarra = await inscrire('sarra@test.tn');
    final karim = await inscrire('karim@test.tn');

    await AdminRepository().publier(
      titre: 'Sortie plage',
      contenu: 'Nous organisons une sortie ce week-end.',
      auteurId: sarra,
    );
    // publier ne renvoie pas l'id : on le relit dans la liste.
    final actualites = await UserRepository().actualites();
    final actu = actualites.firstWhere((a) => a.titre == 'Sortie plage');

    final repo = CommentaireRepository();
    await repo.ajouter(
      actualiteId: actu.id!,
      auteurId: sarra,
      auteurNom: 'Sarra B.',
      contenu: 'J\'y serai !',
    );
    expect(await repo.compter(actu.id!), 1);

    final commentaire = (await repo.lister(actu.id!)).first;
    expect(commentaire is CommentaireActualite, isTrue);

    // Un autre utilisateur ne peut ni modifier ni supprimer.
    expect(await repo.modifier(commentaire.id!, karim, 'Je hijack'), isFalse);
    expect(await repo.supprimer(commentaire.id!, karim), isFalse);

    // L'auteur peut modifier puis supprimer.
    expect(await repo.modifier(commentaire.id!, sarra, 'Je serai là, promis !'), isTrue);
    expect((await repo.lister(actu.id!)).first.contenu, 'Je serai là, promis !');
    expect(await repo.supprimer(commentaire.id!, sarra), isTrue);
    expect(await repo.compter(actu.id!), 0);
  });

  test('photo de profil : définir, relire, retirer', () async {
    final id = await inscrire('photo@test.tn');
    final repo = UserRepository();
    await repo.definirPhoto(id, 'aGVsbG8=');
    final u = (await repo.utilisateurConnecte())!;
    expect(u.photo, 'aGVsbG8=');
    await repo.definirPhoto(id, null);
    expect((await repo.utilisateurConnecte())!.photo, isNull);
  });
}
