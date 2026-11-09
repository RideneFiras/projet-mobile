/// Type de service noté. Stocké en base dans avis.cible_type.
enum CibleAvis {
  location('location', 'Location de voiture'),
  hebergement('hebergement', 'Hébergement'),
  transport('transport', 'Transport');

  const CibleAvis(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static CibleAvis depuis(String valeur) => CibleAvis.values
      .firstWhere((c) => c.valeur == valeur, orElse: () => CibleAvis.transport);
}

/// Avis sur UN service (table "avis"). Note de 1 à 5.
class Avis {
  final int? id;
  final CibleAvis cible;
  final int cibleId;
  final int note;
  final String? commentaire;
  final DateTime creeLe;
  final int auteurId;

  /// Champs issus de la jointure (auteur et nom du service noté).
  final String? nomAuteur;
  final String? libelleCible;

  const Avis({
    this.id,
    required this.cible,
    required this.cibleId,
    required this.note,
    required this.creeLe,
    required this.auteurId,
    this.commentaire,
    this.nomAuteur,
    this.libelleCible,
  });

  factory Avis.fromMap(Map<String, Object?> m) => Avis(
        id: m['id'] as int?,
        cible: CibleAvis.depuis(m['cible_type'] as String),
        cibleId: m['cible_id'] as int,
        note: m['note'] as int,
        commentaire: m['commentaire'] as String?,
        creeLe: DateTime.parse(m['cree_le'] as String),
        auteurId: m['auteur_id'] as int,
        nomAuteur: m['nom_auteur'] as String?,
        libelleCible: m['libelle_cible'] as String?,
      );

  Map<String, Object?> toMap() => {
        'cible_type': cible.valeur,
        'cible_id': cibleId,
        'note': note,
        'commentaire': (commentaire == null || commentaire!.trim().isEmpty)
            ? null
            : commentaire!.trim(),
        'auteur_id': auteurId,
      };
}
