/// Sujet de discussion (table "forum_sujet").
class SujetForum {
  final int? id;
  final String titre;
  final String contenu;
  final DateTime creeLe;
  final int auteurId;

  /// Champs issus de la jointure avec utilisateur et forum_reponse.
  final String? nomAuteur;
  final int nbReponses;

  const SujetForum({
    this.id,
    required this.titre,
    required this.contenu,
    required this.creeLe,
    required this.auteurId,
    this.nomAuteur,
    this.nbReponses = 0,
  });

  factory SujetForum.fromMap(Map<String, Object?> m) => SujetForum(
        id: m['id'] as int?,
        titre: m['titre'] as String,
        contenu: m['contenu'] as String,
        creeLe: DateTime.parse(m['cree_le'] as String),
        auteurId: m['auteur_id'] as int,
        nomAuteur: m['nom_auteur'] as String?,
        nbReponses: (m['nb_reponses'] as int?) ?? 0,
      );

  /// « cree_le » est fixé à la création seulement (voir le repository).
  Map<String, Object?> toMap() => {
        'titre': titre.trim(),
        'contenu': contenu.trim(),
        'auteur_id': auteurId,
      };
}

/// Réponse à un sujet (table "forum_reponse").
class ReponseForum {
  final int? id;
  final String contenu;
  final DateTime creeLe;
  final int sujetId;
  final int auteurId;
  final String? nomAuteur;

  const ReponseForum({
    this.id,
    required this.contenu,
    required this.creeLe,
    required this.sujetId,
    required this.auteurId,
    this.nomAuteur,
  });

  factory ReponseForum.fromMap(Map<String, Object?> m) => ReponseForum(
        id: m['id'] as int?,
        contenu: m['contenu'] as String,
        creeLe: DateTime.parse(m['cree_le'] as String),
        sujetId: m['sujet_id'] as int,
        auteurId: m['auteur_id'] as int,
        nomAuteur: m['nom_auteur'] as String?,
      );
}
