import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/modules/user/actualite.dart';
import 'package:projet_mobile/modules/user/actualite_fil.dart';
import 'package:projet_mobile/modules/user/role.dart';

Actualite actu(String id, {
  String titre = 'Titre',
  String contenu = 'Contenu assez long',
  DateTime? date,
  AudienceActualite audience = AudienceActualite.tous,
  CategorieActualite categorie = CategorieActualite.general,
}) =>
    Actualite(
      titre: '$titre $id',
      contenu: '$contenu $id',
      datePublication: date ?? DateTime(2026, 11, 1),
      audience: audience,
      categorie: categorie,
    );

void main() {
  group('FilActualites', () {
    test('valider : titre et contenu', () {
      expect(FilActualites.valider(' Un titre valide ', ' Un contenu valide et assez long '), isNull);
      expect(FilActualites.valider('ab', 'Contenu valide et assez long'), isNotNull);
      expect(FilActualites.valider('Titre valide', 'court'), isNotNull);
    });

    test('valider : en sondage, la question remplace le texte', () {
      expect(FilActualites.valider('Quelle destination ?', '', sondage: true), isNull);
      expect(FilActualites.valider('Quelle destination ?', ''), isNotNull);
    });

    test('estVisiblePour : fil commun, tout le monde voit tout', () {
      expect(FilActualites.estVisiblePour(actu('1'), Role.transporter), isTrue);
      expect(FilActualites.estVisiblePour(actu('2', audience: AudienceActualite.client), Role.traveller), isTrue);
      expect(FilActualites.estVisiblePour(actu('2'), null), isTrue);
    });

    test('peutModifier : auteur seulement (jamais les publications des autres)', () {
      final a = Actualite(
        titre: 'Titre',
        contenu: 'Contenu assez long',
        datePublication: DateTime(2026, 11, 1),
        auteurId: 42,
      );
      expect(FilActualites.peutModifier(a, utilisateurId: 42, role: Role.client), isTrue);
      expect(FilActualites.peutModifier(a, utilisateurId: 99, role: Role.traveller), isFalse);
      expect(FilActualites.peutModifier(a, utilisateurId: 99, role: Role.admin), isFalse);
      expect(FilActualites.peutModifier(a, utilisateurId: null, role: Role.client), isFalse);
    });

    test('filtrer : recherche sans accents, catégorie, tri récent', () {
      final vieux = actu('1', titre: 'Bonne année', date: DateTime(2026, 1, 1));
      final recent = actu('2',
          titre: 'Nouvelle commande',
          date: DateTime(2026, 11, 8),
          audience: AudienceActualite.client,
          categorie: CategorieActualite.commande);
      final autre = actu('3',
          titre: 'Autre sujet',
          date: DateTime(2026, 11, 9),
          audience: AudienceActualite.traveller);

      // Fil commun : les trois sont visibles, triées de la plus récente.
      expect(
        FilActualites.filtrer([vieux, recent, autre], role: Role.client).map((a) => a.titre),
        ['Autre sujet 3', 'Nouvelle commande 2', 'Bonne année 1'],
      );
      expect(
        FilActualites.filtrer([vieux, recent], role: Role.client, recherche: 'annee').map((a) => a.titre),
        ['Bonne année 1'],
      );
      expect(
        FilActualites.filtrer([vieux, recent], role: Role.client, categorie: CategorieActualite.general).map((a) => a.titre),
        ['Bonne année 1'],
      );
    });

    test('tempsRelatif : comme Facebook', () {
      final maintenant = DateTime.now();
      expect(FilActualites.tempsRelatif(maintenant.subtract(const Duration(seconds: 10))), "à l'instant");
      expect(FilActualites.tempsRelatif(maintenant.subtract(const Duration(minutes: 5))), 'il y a 5 min');
      expect(FilActualites.tempsRelatif(maintenant.subtract(const Duration(hours: 3))), 'il y a 3 h');
      expect(FilActualites.tempsRelatif(maintenant.subtract(const Duration(days: 2))), 'il y a 2 j');
    });

    test('extrait : coupe sans couper un mot', () {
      expect(FilActualites.extrait('bonjour'), 'bonjour');
      final long = List.filled(50, 'word').join(' ');
      final ex = FilActualites.extrait(long, max: 20);
      expect(ex.endsWith('…'), isTrue);
    });
  });
}
