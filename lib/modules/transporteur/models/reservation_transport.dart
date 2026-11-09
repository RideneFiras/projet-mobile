/// Statut d'un trajet proposé par un transporteur (colonne "statut").
enum StatutTrajet {
  enAttente('en_attente', 'En attente'),
  confirmee('confirmee', 'Confirmée'),
  annulee('annulee', 'Annulée');

  const StatutTrajet(this.valeur, this.libelle);
  final String valeur;
  final String libelle;

  static StatutTrajet depuis(String v) =>
      StatutTrajet.values.firstWhere((s) => s.valeur == v,
          orElse: () => StatutTrajet.enAttente);
}

/// Trajet proposé par un transporteur (table "reservation_transport").
/// [dateDepart] est stockée au format ISO "yyyy-MM-dd".
class ReservationTransport {
  final int? id;
  final String depart;
  final String arrivee;
  final DateTime dateDepart;
  final double prix;
  final StatutTrajet statut;
  final int? transporteurId;
  final String? nomTransporteur;
  final int? voyageId;

  const ReservationTransport({
    this.id,
    required this.depart,
    required this.arrivee,
    required this.dateDepart,
    required this.prix,
    this.statut = StatutTrajet.enAttente,
    this.transporteurId,
    this.nomTransporteur,
    this.voyageId,
  });

  factory ReservationTransport.fromMap(Map<String, dynamic> m) =>
      ReservationTransport(
        id: m['id'] as int?,
        depart: m['depart'] as String,
        arrivee: m['arrivee'] as String,
        dateDepart: DateTime.parse(m['date_depart'] as String),
        prix: (m['prix'] as num).toDouble(),
        statut: StatutTrajet.depuis(m['statut'] as String),
        transporteurId: m['transporteur_id'] as int?,
        nomTransporteur: m['nom_transporteur'] as String?,
        voyageId: m['voyage_id'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'depart': depart.trim(),
        'arrivee': arrivee.trim(),
        'date_depart': dateIso(dateDepart),
        'prix': prix,
        'statut': statut.valeur,
        'transporteur_id': transporteurId,
        'voyage_id': voyageId,
      };

  static String dateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
