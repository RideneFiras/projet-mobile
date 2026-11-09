/// Une option d'un sondage attaché à une actualité (post-sondage).
class OptionSondage {
  final int? id;
  final int actualiteId;
  final String libelle;
  final int ordre;

  const OptionSondage({
    this.id,
    required this.actualiteId,
    required this.libelle,
    this.ordre = 0,
  });

  factory OptionSondage.fromMap(Map<String, dynamic> m) => OptionSondage(
        id: m['id'] as int?,
        actualiteId: m['actualite_id'] as int,
        libelle: m['libelle'] as String,
        ordre: (m['ordre'] as int?) ?? 0,
      );
}

/// Résultat d'une option : nombre de votes et pourcentage.
class ResultatSondage {
  final OptionSondage option;
  final int votes;
  final double pourcentage;
  final bool choisi;

  const ResultatSondage({
    required this.option,
    required this.votes,
    required this.pourcentage,
    required this.choisi,
  });
}
