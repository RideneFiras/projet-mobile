import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/user/admin_repository.dart';
import 'package:projet_mobile/modules/user/actualite.dart';
import 'package:projet_mobile/modules/user/message_repository.dart';
import 'package:projet_mobile/modules/user/notification_repository.dart';
import 'package:projet_mobile/modules/user/participation_repository.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Notifications, messenger, épingler et posts annonces du fil.
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

  test('notifications : réagir à un post notifie son auteur, jamais soi-même', () async {
    final auteur = await inscrire('auteur3@test.tn', 'Sarra');
    final autre = await inscrire('autre3@test.tn', 'Karim');
    await AdminRepository().publier(
      titre: 'Mon post',
      contenu: 'Contenu assez long pour passer.',
      auteurId: auteur,
    );
    final actu = (await UserRepository().actualites()).firstWhere((a) => a.titre == 'Mon post');

    final repo = NotificationRepository();
    // L'autre réagit au post.
    await repo.notifier(
      destinataireId: auteur,
      acteurId: autre,
      acteurNom: 'Karim Test',
      type: 'commentaire',
      actualiteId: actu.id,
      texte: 'Karim Test a commenté ton post « Mon post »',
    );
    expect(await repo.nonLues(auteur), 1);
    expect(await repo.nonLues(autre), 0);
    final liste = await repo.lister(auteur);
    expect(liste.first.texte, contains('Karim Test'));
    await repo.toutMarquerLu(auteur);
    expect(await repo.nonLues(auteur), 0);

    // Réagir à son propre post : aucune notification.
    await repo.notifier(
      destinataireId: auteur,
      acteurId: auteur,
      acteurNom: 'Sarra Test',
      type: 'reaction',
      actualiteId: actu.id,
      texte: 'ne doit pas arriver',
    );
    expect(await repo.nonLues(auteur), 0);
  });

  test('cross-comptes : le post du premier reste visible pour le deuxième', () async {
    final sarra = await inscrire('cross1@test.tn', 'Sarra');
    final karim = await inscrire('cross2@test.tn', 'Karim');
    await AdminRepository().publier(
      titre: 'Post de Sarra',
      contenu: 'Contenu assez long pour passer.',
      auteurId: sarra,
    );
    // Karim (autre compte, autre session) ouvre le fil : il voit le post de Sarra.
    final fil = await UserRepository().actualites();
    final vu = fil.firstWhere((a) => a.titre == 'Post de Sarra');
    expect(vu.auteurNom, contains('Sarra'));
    expect(vu.auteurId, sarra);
    // Et Sarra voit aussi les posts de Karim.
    await AdminRepository().publier(
      titre: 'Post de Karim',
      contenu: 'Contenu assez long pour passer.',
      auteurId: karim,
    );
    final titres = (await UserRepository().actualites()).map((a) => a.titre);
    expect(titres, containsAll(['Post de Sarra', 'Post de Karim']));
  });

  test('messenger : conversation entre deux utilisateurs', () async {
    final moi = await inscrire('moi@test.tn', 'Moi');
    final autre = await inscrire('lui@test.tn', 'Lui');
    final repo = MessageRepository();
    await repo.envoyer(expediteurId: moi, destinataireId: autre, contenu: 'Bonjour !');
    await repo.envoyer(expediteurId: autre, destinataireId: moi, contenu: 'Salut !');

    final fil = await repo.conversation(moi, autre);
    expect(fil.length, 2);
    expect(fil.first.contenu, 'Bonjour !');
    expect(fil.last.contenu, 'Salut !');

    final convs = await repo.conversations(moi);
    expect(convs.length, 1);
    expect(convs.first.autreId, autre);
    expect(convs.first.dernierMessage, 'Salut !');
  });

  test('epingler : auteur seul, le post remonte en haut du fil', () async {
    final auteur = await inscrire('eping@test.tn', 'Eping');
    final autre = await inscrire('eping2@test.tn', 'Autre');
    await AdminRepository().publier(
      titre: 'Premier post',
      contenu: 'Contenu assez long pour passer.',
      auteurId: auteur,
    );
    await AdminRepository().publier(
      titre: 'Second post',
      contenu: 'Contenu assez long pour passer.',
      auteurId: auteur,
    );
    var liste = await UserRepository().actualites();
    final premier = liste.firstWhere((a) => a.titre == 'Premier post');

    // Un autre ne peut pas épingler.
    expect(await AdminRepository().epingler(premier.id!, autre, true), isFalse);
    // L'auteur épingle : son post passe premier.
    expect(await AdminRepository().epingler(premier.id!, auteur, true), isTrue);
    liste = await UserRepository().actualites();
    expect(liste.first.titre, 'Premier post');
    expect(liste.first.epingle, isTrue);
  });

  test('post annonce : participer est unique, retirer possible', () async {
    final auteur = await inscrire('annonce@test.tn', 'Annonceur');
    final autre = await inscrire('annonce2@test.tn', 'Participe');
    await AdminRepository().publier(
      titre: 'Sortie plage',
      contenu: 'Sortie organisée ce week-end.',
      auteurId: auteur,
      typePost: TypePost.annonce,
      dateEvenement: DateTime(2026, 12, 1).toIso8601String(),
      lieu: 'La Marsa',
    );
    final actu = (await UserRepository().actualites()).firstWhere((a) => a.titre == 'Sortie plage');
    expect(actu.typePost, TypePost.annonce);
    expect(actu.lieu, 'La Marsa');

    final repo = ParticipationRepository();
    expect(await repo.basculer(
        actualiteId: actu.id!, utilisateurId: autre, auteurId: auteur, acteurNom: 'Participe Test'), isTrue);
    expect(await repo.compter(actu.id!), 1);
    // L'auteur est notifié de la participation.
    expect(await NotificationRepository().nonLues(auteur), 1);
    // Retirer.
    expect(await repo.basculer(actualiteId: actu.id!, utilisateurId: autre), isFalse);
    expect(await repo.compter(actu.id!), 0);
  });
}
