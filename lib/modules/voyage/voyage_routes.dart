/// Routes du module Voyage et correspondance avec les tuiles de l'accueil.
class VoyageRoutes {
  VoyageRoutes._();

  static const String liste = '/voyage/liste';
  static const String nouveau = '/voyage/nouveau';

  /// Route correspondant au titre d'une tuile, ou null si la tuile n'est pas à nous.
  static String? pour(String titre) => switch (titre) {
        'Mes voyages' => liste,
        'Nouveau voyage' => nouveau,
        _ => null,
      };
}
