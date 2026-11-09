import 'offre_vol.dart';

/// Le vol retenu pour un voyage : quelle offre, quelle classe, quel prix final.
class VoyageVol {
  final int? id;
  final int voyageId;
  final int offreId;
  final ClasseVol classe;
  final double prix;

  const VoyageVol({
    this.id,
    required this.voyageId,
    required this.offreId,
    required this.classe,
    required this.prix,
  });

  factory VoyageVol.fromMap(Map<String, Object?> m) => VoyageVol(
    id: m['id'] as int?,
    voyageId: m['voyage_id'] as int,
    offreId: m['offre_id'] as int,
    classe: ClasseVol.depuis(m['classe'] as String),
    prix: (m['prix'] as num).toDouble(),
  );

  Map<String, Object?> toMap() => {
    'voyage_id': voyageId,
    'offre_id': offreId,
    'classe': classe.valeur,
    'prix': prix,
  };
}
