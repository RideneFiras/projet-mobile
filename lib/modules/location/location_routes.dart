/// Routes du module Location et correspondance avec les tuiles de l'accueil.
class LocationRoutes {
  LocationRoutes._();

  /// Voyageur : parcourir les véhicules, réserver pour un voyage, suivre ses locations.
  static const String accueil = '/location';

  /// Administrateur : gérer la flotte (ajout, modification, suppression).
  static const String gestion = '/location/gestion';

  static String? pour(String titre) => switch (titre) {
        'Location de voiture' => accueil,
        'Gérer la flotte' => gestion,
        _ => null,
      };
}
