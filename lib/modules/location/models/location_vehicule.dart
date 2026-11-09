import '../../../core/utils/dates.dart';

/// Location d'un véhicule pour un voyage (table "location_vehicule").
/// Règles : prix_total = prix_par_jour x jours (bornes comprises) ;
/// deux locations du même véhicule ne se chevauchent jamais.
class LocationVehicule {
  final int? id;
  final DateTime dateDebut;
  final DateTime dateFin;
  final double prixTotal;
  final int voyageId;
  final int vehiculeId;

  /// Champs d'affichage issus de la jointure (absents à la saisie).
  final String? nomVehicule;
  final String? titreVoyage;

  const LocationVehicule({
    this.id,
    required this.dateDebut,
    required this.dateFin,
    required this.voyageId,
    required this.vehiculeId,
    this.prixTotal = 0,
    this.nomVehicule,
    this.titreVoyage,
  });

  /// Nombre de jours loués, bornes comprises (même jour = 1 jour).
  int get jours => nombreDeJours(dateDebut, dateFin) + 1;

  /// Règle de la base : la date de fin ne précède pas la date de début.
  static String? verifierPeriode(DateTime debut, DateTime fin) {
    if (dateJour(fin).isBefore(dateJour(debut))) {
      return 'La date de retour doit être après la date de prise en charge';
    }
    return null;
  }

  factory LocationVehicule.fromMap(Map<String, Object?> m) => LocationVehicule(
        id: m['id'] as int?,
        dateDebut: DateTime.parse(m['date_debut'] as String),
        dateFin: DateTime.parse(m['date_fin'] as String),
        prixTotal: (m['prix_total'] as num).toDouble(),
        voyageId: m['voyage_id'] as int,
        vehiculeId: m['vehicule_id'] as int,
        nomVehicule: m['nom_vehicule'] as String?,
        titreVoyage: m['titre_voyage'] as String?,
      );

  /// Le prix n'est pas repris d'ici : le repository le recalcule à l'enregistrement.
  Map<String, Object?> toMap() => {
        'date_debut': dateIso(dateDebut),
        'date_fin': dateIso(dateFin),
        'prix_total': prixTotal,
        'voyage_id': voyageId,
        'vehicule_id': vehiculeId,
      };
}
