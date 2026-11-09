import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/modules/transporteur/transport_trajet_api.dart';

void main() {
  group('Itinéraire', () {
    test('Estimation : marquée comme estimée, sans alternatives', () {
      final it = ItineraireTrajet.depuisJson({
        'depart': 'Tunis',
        'arrivee': 'Sfax',
        'source': 'estimation',
        'recommande': {'distance_km': 240.5, 'duree_min': 206},
        'alternatives': [],
        'avertissement': 'OPENROUTESERVICE_API_KEY absente',
      });
      expect(it.estime, isTrue);
      expect(it.recommande.distanceKm, 240.5);
      expect(it.recommande.dureeMin, 206);
      expect(it.alternatives, isEmpty);
      expect(it.avertissement, isNotNull);
    });

    test('OpenRouteService : routes alternatives lues, entiers acceptés', () {
      final it = ItineraireTrajet.depuisJson({
        'depart': 'Tunis',
        'arrivee': 'Hammamet',
        'source': 'openrouteservice',
        'recommande': {'distance_km': 65, 'duree_min': 55},
        'alternatives': [
          {'distance_km': 70, 'duree_min': 61},
        ],
        'avertissement': null,
      });
      expect(it.estime, isFalse);
      expect(it.recommande.distanceKm, 65.0);
      expect(it.alternatives, hasLength(1));
      expect(it.alternatives.first.dureeMin, 61);
      expect(it.avertissement, isNull);
    });

    test('Champ obligatoire absent : erreur de type, interceptée par le service', () {
      expect(
        () => ItineraireTrajet.depuisJson({'depart': 'Tunis'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
