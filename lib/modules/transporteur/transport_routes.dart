  /// Routes nommées du module transporteur.
/// app_routes.dart associe chaque chemin à son écran ; les tuiles de l'accueil
/// utilisent [pour] pour trouver l'écran à ouvrir à partir du titre de la tuile.
class TransportRoutes {
  TransportRoutes._();

  static const String commandeNouvelle = '/transport/commande/nouvelle';
  static const String mesCommandes = '/transport/commandes';
  static const String commandesOuvertes = '/transport/ouvertes';
  static const String relations = '/transport/relations';
  static const String reservations = '/transport/reservations';
  static const String voyageur = '/transport/voyageur';
  static const String transporteurs = '/transport/transporteurs';

  /// Chemin de l'écran associé à la tuile [titre], ou null si la tuile
  /// n'appartient pas au module transporteur.
  static String? pour(String titre) => switch (titre) {
        'Nouvelle commande' => commandeNouvelle,
        'Mes commandes' => mesCommandes,
        'Commandes ouvertes' => commandesOuvertes,
        'Mises en relation' => relations,
        'Réservations' => reservations,
        'Transport' => voyageur,
        'Mon profil transporteur' => transporteurs,
        _ => null,
      };
}
