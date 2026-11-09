import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/modules/user/actualite.dart';
import 'package:projet_mobile/modules/user/actualite_api.dart';
import 'package:projet_mobile/modules/user/actualite_fil.dart';

void main() {
  group('ActualiteApi', () {
    test('brouillonLocal : gabarit valide, sans prix ni date inventée', () {
      final b = ActualiteApi.brouillonLocal(theme: 'nouvelles destinations', categorie: CategorieActualite.voyage);
      expect(b.source, SourceBrouillon.local);
      expect(b.titre, 'Nouvelles destinations');
      expect(FilActualites.valider(b.titre, b.contenu), isNull);
    });

    test('Actualite.fromMap lit le JSON de l API (audience, categorie)', () {
      final a = Actualite.fromMap({
        'id': 7,
        'titre': 'Offre',
        'contenu': 'Contenu assez long',
        'date_publication': '2026-11-08T10:00:00.000Z',
        'auteur_id': null,
        'audience': 'traveller',
        'categorie': 'voyage',
      });
      expect(a.audience, AudienceActualite.traveller);
      expect(a.categorie, CategorieActualite.voyage);
    });

    test('Actualite.fromMap lit la photo du post (base64)', () {
      final a = Actualite.fromMap({
        'id': 3,
        'titre': 'Photo',
        'contenu': 'Contenu assez long',
        'photo': 'aGVsbG8=',
        'date_publication': '2026-11-08T10:00:00.000Z',
        'auteur_id': 5,
      });
      expect(a.photo, 'aGVsbG8=');
    });

    test('Actualite.fromMap sans audience ni categorie : valeurs par défaut', () {
      final a = Actualite.fromMap({
        'id': 1,
        'titre': 'Ancien format',
        'contenu': 'Contenu assez long',
        'date_publication': '2026-11-08T10:00:00.000Z',
        'auteur_id': null,
      });
      expect(a.audience, AudienceActualite.tous);
      expect(a.categorie, CategorieActualite.general);
    });
  });
}
