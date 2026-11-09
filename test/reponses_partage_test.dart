import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/database/database_helper.dart';
import 'package:projet_mobile/modules/user/admin_repository.dart';
import 'package:projet_mobile/modules/user/commentaire_repository.dart';
import 'package:projet_mobile/modules/user/partage_repository.dart';
import 'package:projet_mobile/modules/user/reaction_commentaire_repository.dart';
import 'package:projet_mobile/modules/user/role.dart';
import 'package:projet_mobile/modules/user/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Réponses aux commentaires, réactions sur commentaires et partage
/// (règles auteur seul pour modifier/supprimer).
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

  test('réponse à un commentaire + réaction sur commentaire (auteur seul)', () async {
    final y = await inscrire('y@test.tn', 'Yasmine');
    final x = await inscrire('x@test.tn', 'Karim');
    await AdminRepository().publier(
      titre: 'Post de Yasmine',
      contenu: 'Contenu assez long pour passer.',
      auteurId: y,
    );
    final post = (await UserRepository().actualites())
        .firstWhere((a) => a.titre == 'Post de Yasmine');

    final commentaires = CommentaireRepository();
    await commentaires.ajouter(
      actualiteId: post.id!,
      auteurId: x,
      auteurNom: 'Karim Test',
      contenu: 'Super post !',
    );
    final commentaire = (await commentaires.lister(post.id!)).first;

    // Yasmine peut répondre à Karim.
    await commentaires.ajouter(
      actualiteId: post.id!,
      parentId: commentaire.id,
      auteurId: y,
      auteurNom: 'Yasmine Test',
      contenu: 'Merci Karim !',
    );
    final reponses = await commentaires.reponses(commentaire.id!);
    expect(reponses.length, 1);
    expect(reponses.first.auteurNom, contains('Yasmine'));

    // Réaction sur le commentaire de Karim, par Yasmine.
    final reactions = ReactionCommentaireRepository();
    expect(await reactions.choisir(commentaire.id!, y, 'love'), 'love');
    expect(await reactions.maReaction(commentaire.id!, y), 'love');
    expect(await reactions.compter(commentaire.id!), 1);
    // Même type : retire.
    expect(await reactions.choisir(commentaire.id!, y, 'love'), isNull);
    expect(await reactions.compter(commentaire.id!), 0);
  });

  test('partage : enregistré une fois, visible dans le profil du partageur', () async {
    final x = await inscrire('px@test.tn', 'Karim');
    final y = await inscrire('py@test.tn', 'Yasmine');
    await AdminRepository().publier(
      titre: 'Post à partager',
      contenu: 'Contenu assez long pour passer.',
      auteurId: x,
    );
    final post = (await UserRepository().actualites())
        .firstWhere((a) => a.titre == 'Post à partager');

    final partage = PartageRepository();
    expect(await partage.basculer(actualiteId: post.id!, utilisateurId: y), isTrue);
    // Re-toucher : retire (un seul partage par utilisateur).
    expect(await partage.basculer(actualiteId: post.id!, utilisateurId: y), isFalse);
    expect(await partage.compter(post.id!), 0);

    // Re-partage avant l'affichage dans le profil.
    await partage.basculer(actualiteId: post.id!, utilisateurId: y);
    final ids = await partage.idsPartages(y);
    expect(ids, contains(post.id));
    final fil = await UserRepository().actualites();
    final partageVu = fil.firstWhere((a) => a.id == post.id);
    expect(partageVu.auteurNom, contains('Karim'));
  });
}
