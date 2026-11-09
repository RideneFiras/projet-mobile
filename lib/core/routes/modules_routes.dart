import '../../modules/forum/forum_routes.dart';
import '../../modules/hebergement/hebergement_routes.dart';
import '../../modules/location/location_routes.dart';
import '../../modules/transporteur/transport_routes.dart';
import '../../modules/user/admin_routes.dart';
import '../../modules/voyage/voyage_routes.dart';

/// Point d'entrée unique pour les tuiles de l'accueil : chaque module déclare
/// ses titres dans son propre fichier de routes, ce fichier les rassemble.
class ModulesRoutes {
  ModulesRoutes._();

  /// Route de la tuile [titre], ou null si aucun module ne la gère (écran « à venir »).
  static String? pour(String titre) =>
      TransportRoutes.pour(titre) ??
      VoyageRoutes.pour(titre) ??
      LocationRoutes.pour(titre) ??
      HebergementRoutes.pour(titre) ??
      ForumRoutes.pour(titre) ??
      AdminRoutes.pour(titre);
}
