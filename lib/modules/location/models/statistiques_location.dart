import 'vehicule.dart';

/// Indicateurs de l'onglet admin « Réservations », calculés en SQL par
/// LocationRepository.statistiques().
class StatistiquesLocation {
  /// Fenêtre glissante utilisée pour le taux d'occupation.
  static const int periodeJours = 30;

  /// Locations non annulées et non clôturées (à venir, en cours ou en retard).
  final int actives;

  /// Parmi les actives : déjà commencées.
  final int enCours;

  /// Parmi les actives : date de retour prévue dépassée.
  final int enRetard;

  /// Somme (prix_total + pénalité) des locations non annulées.
  final double chiffreAffaires;

  final String? vehiculePlusLoue;
  final int locationsVehiculePlusLoue;

  /// Taux d'occupation (0 à 1) par type sur les [periodeJours] derniers jours.
  /// Un type sans véhicule n'apparaît pas.
  final Map<TypeVehicule, double> tauxOccupation;

  /// Chiffre d'affaires (hors annulations, pénalités comprises) par type de véhicule.
  final Map<TypeVehicule, double> revenusParType;

  /// Véhicules au statut « maintenance ».
  final int enMaintenance;

  /// Véhicules dont la révision est due (intervalle de kilométrage atteint).
  final int revisionsDues;

  const StatistiquesLocation({
    this.actives = 0,
    this.enCours = 0,
    this.enRetard = 0,
    this.chiffreAffaires = 0,
    this.vehiculePlusLoue,
    this.locationsVehiculePlusLoue = 0,
    this.tauxOccupation = const {},
    this.revenusParType = const {},
    this.enMaintenance = 0,
    this.revisionsDues = 0,
  });
}
