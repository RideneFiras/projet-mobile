/// Routes du module Forum et correspondance avec les tuiles de l'accueil.
class ForumRoutes {
  ForumRoutes._();

  /// Forum, ouvert sur l'onglet Discussions.
  static const String forum = '/forum';

  /// Même écran, ouvert directement sur l'onglet Avis.
  static const String avis = '/forum/avis';

  static String? pour(String titre) => switch (titre) {
        'Forum' => forum,
        'Avis sur les transporteurs' => avis,
        _ => null,
      };
}
