/// Version archivée d'un post (historique des modifications/suppressions).
/// Conservée même après suppression du post (table sans clé étrangère).
class VersionPost {
  final int? id;
  final int actualiteId;
  final String titre;
  final String contenu;
  final int? auteurId;
  /// modification | suppression
  final String action;
  final DateTime creeLe;

  const VersionPost({
    this.id,
    required this.actualiteId,
    required this.titre,
    required this.contenu,
    this.auteurId,
    required this.action,
    required this.creeLe,
  });

  factory VersionPost.fromMap(Map<String, dynamic> m) => VersionPost(
        id: m['id'] as int?,
        actualiteId: m['actualite_id'] as int,
        titre: m['titre'] as String,
        contenu: m['contenu'] as String,
        auteurId: m['auteur_id'] as int?,
        action: m['action'] as String,
        creeLe: DateTime.parse(m['cree_le'] as String),
      );
}
