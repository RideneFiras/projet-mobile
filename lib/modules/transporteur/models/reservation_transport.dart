/// Statut d'une réservation confirmée (colonne "statut").
enum StatutReservation {
  confirmee('confirmee', 'Confirmée'),
  priseEnCharge('prise_en_charge', 'Prise en charge'),
  annulee('annulee', 'Annulée');

  const StatutReservation(this.valeur, this.libelle);
  final String valeur;
  final String libelle;

  static StatutReservation depuis(String v) =>
      StatutReservation.values.firstWhere((s) => s.valeur == v,
          orElse: () => StatutReservation.confirmee);
}

/// Réservation confirmée (table "reservation_transport"). Elle n'existe qu'après
/// l'acceptation d'une proposition. Les champs de jointure viennent du trajet,
/// du voyageur et du transporteur.
class ReservationTransport {
  final int? id;
  final int trajetId;
  final int voyageurId;
  final int? commandeId;
  final int nombrePlaces;
  final StatutReservation statut;
  final String motifAnnulation;

  final DateTime creeLe;

  final String nomVoyageur;
  final String telephoneVoyageur;
  final String villeDepart;
  final String destination;
  final DateTime dateDepart;
  final double prixParPersonne;
  final String nomTransporteur;
  final String telephoneTransporteur;

  const ReservationTransport({
    this.id,
    required this.trajetId,
    required this.voyageurId,
    this.commandeId,
    required this.nombrePlaces,
    this.statut = StatutReservation.confirmee,
    this.motifAnnulation = '',
    required this.creeLe,
    this.nomVoyageur = '',
    this.telephoneVoyageur = '',
    this.villeDepart = '',
    this.destination = '',
    required this.dateDepart,
    this.prixParPersonne = 0,
    this.nomTransporteur = '',
    this.telephoneTransporteur = '',
  });

  bool get active => statut != StatutReservation.annulee;

  factory ReservationTransport.fromMap(Map<String, dynamic> m) =>
      ReservationTransport(
        id: m['id'] as int?,
        trajetId: m['trajet_id'] as int,
        voyageurId: m['voyageur_id'] as int,
        commandeId: m['commande_id'] as int?,
        nombrePlaces: m['nombre_places'] as int,
        statut: StatutReservation.depuis(m['statut'] as String),
        motifAnnulation: (m['motif_annulation'] as String?) ?? '',
        creeLe: DateTime.parse(m['cree_le'] as String),
        nomVoyageur: (m['nom_voyageur'] as String?) ?? '',
        telephoneVoyageur: (m['telephone_voyageur'] as String?) ?? '',
        villeDepart: (m['ville_depart'] as String?) ?? '',
        destination: (m['destination'] as String?) ?? '',
        dateDepart: DateTime.parse(m['date_depart'] as String),
        prixParPersonne: ((m['prix_par_personne'] as num?) ?? 0).toDouble(),
        nomTransporteur: (m['nom_transporteur'] as String?) ?? '',
        telephoneTransporteur: (m['telephone_transporteur'] as String?) ?? '',
      );
}

/// Ligne de l'historique d'une réservation (table "historique_reservation").
class EvenementReservation {
  final String evenement;
  final DateTime creeLe;

  const EvenementReservation({required this.evenement, required this.creeLe});

  factory EvenementReservation.fromMap(Map<String, dynamic> m) =>
      EvenementReservation(
        evenement: m['evenement'] as String,
        creeLe: DateTime.parse(m['cree_le'] as String),
      );
}
