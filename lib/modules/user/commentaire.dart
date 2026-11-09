/// Commentaire d'une actualité (réponse dans le fil, comme sous un post).
/// Seul son auteur peut le modifier ou le supprimer.
class CommentaireActualite {
  final int? id;
  final int actualiteId;
  /// Réponse à un autre commentaire (null = commentaire racine).
  final int? parentId;
  final int? auteurId;
  final String auteurNom;
  /// Type de l'auteur (client/voyageur/transporteur/admin), via jointure.
  final String? auteurRole;
  final String contenu;
  final DateTime creeLe;

  const CommentaireActualite({
    this.id,
    required this.actualiteId,
    this.parentId,
    this.auteurId,
    required this.auteurNom,
    this.auteurRole,
    required this.contenu,
    required this.creeLe,
  });

  bool get estReponse => parentId != null;

  factory CommentaireActualite.fromMap(Map<String, dynamic> m) =>
      CommentaireActualite(
        id: m['id'] as int?,
        actualiteId: m['actualite_id'] as int,
        parentId: m['parent_id'] as int?,
        auteurId: m['auteur_id'] as int?,
        auteurNom: m['auteur_nom'] as String,
        auteurRole: m['auteur_role'] as String?,
        contenu: m['contenu'] as String,
        creeLe: DateTime.parse(m['cree_le'] as String),
      );
}
