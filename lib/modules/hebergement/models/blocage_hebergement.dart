import '../../../core/utils/dates.dart';

/// Période de fermeture d'un établissement (table "blocage_hebergement") :
/// travaux, fermeture saisonnière, usage du propriétaire… Aucune nuit réservable.
class BlocageHebergement {
  final int? id;
  final int hebergementId;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String? motif;

  const BlocageHebergement({
    this.id,
    required this.hebergementId,
    required this.dateDebut,
    required this.dateFin,
    this.motif,
  });

  String? verifier() {
    if (dateJour(dateFin).isBefore(dateJour(dateDebut))) {
      return 'La fin de la fermeture doit suivre son début';
    }
    return null;
  }

  factory BlocageHebergement.fromMap(Map<String, Object?> m) => BlocageHebergement(
        id: m['id'] as int?,
        hebergementId: m['hebergement_id'] as int,
        dateDebut: DateTime.parse(m['date_debut'] as String),
        dateFin: DateTime.parse(m['date_fin'] as String),
        motif: m['motif'] as String?,
      );

  Map<String, Object?> toMap() => {
        'hebergement_id': hebergementId,
        'date_debut': dateIso(dateDebut),
        'date_fin': dateIso(dateFin),
        'motif': (motif == null || motif!.trim().isEmpty) ? null : motif!.trim(),
      };
}
