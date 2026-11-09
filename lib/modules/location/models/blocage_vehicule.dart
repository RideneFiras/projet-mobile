import '../../../core/utils/dates.dart';

/// Période pendant laquelle un véhicule n'est pas réservable (table "blocage_vehicule") :
/// entretien, réparation, usage personnel du propriétaire…
class BlocageVehicule {
  final int? id;
  final int vehiculeId;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String? motif;

  const BlocageVehicule({
    this.id,
    required this.vehiculeId,
    required this.dateDebut,
    required this.dateFin,
    this.motif,
  });

  String? verifier() {
    if (dateJour(dateFin).isBefore(dateJour(dateDebut))) {
      return 'La fin du blocage doit suivre son début';
    }
    return null;
  }

  factory BlocageVehicule.fromMap(Map<String, Object?> m) => BlocageVehicule(
        id: m['id'] as int?,
        vehiculeId: m['vehicule_id'] as int,
        dateDebut: DateTime.parse(m['date_debut'] as String),
        dateFin: DateTime.parse(m['date_fin'] as String),
        motif: m['motif'] as String?,
      );

  Map<String, Object?> toMap() => {
        'vehicule_id': vehiculeId,
        'date_debut': dateIso(dateDebut),
        'date_fin': dateIso(dateFin),
        'motif': (motif == null || motif!.trim().isEmpty) ? null : motif!.trim(),
      };
}
