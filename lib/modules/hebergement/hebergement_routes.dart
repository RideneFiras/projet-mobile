/// Routes du module Hébergement et correspondance avec les tuiles de l'accueil.
class HebergementRoutes {
  HebergementRoutes._();

  /// Voyageur : parcourir les établissements, réserver un séjour, suivre ses séjours.
  static const String accueil = '/hebergement';

  /// Administrateur : gérer le catalogue des établissements.
  static const String gestion = '/hebergement/gestion';

  static String? pour(String titre) => switch (titre) {
        'Hébergement' => accueil,
        'Gérer les établissements' => gestion,
        _ => null,
      };
}
