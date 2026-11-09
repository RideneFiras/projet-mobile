/// Routes de l'espace administrateur et correspondance avec les tuiles de l'accueil.
class AdminRoutes {
  AdminRoutes._();

  static const String actualites = '/admin/actualites';
  static const String actualiteNouvelle = '/admin/actualites/nouvelle';
  static const String utilisateurs = '/admin/utilisateurs';

  static String? pour(String titre) => switch (titre) {
        'Publier une actualité' => actualiteNouvelle,
        'Gérer les actualités' => actualites,
        'Utilisateurs' => utilisateurs,
        _ => null,
      };
}
