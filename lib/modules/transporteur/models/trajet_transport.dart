import '../transport_format.dart';

/// Statut d'un trajet (colonne "statut"). Changements : planifié → en cours ou annulé ;
/// en cours → terminé.
enum StatutTrajet {
  planifie('planifie', 'Planifié'),
  enCours('en_cours', 'En cours'),
  termine('termine', 'Terminé'),
  annule('annule', 'Annulé');

  const StatutTrajet(this.valeur, this.libelle);
  final String valeur;
  final String libelle;

  static StatutTrajet depuis(String v) =>
      StatutTrajet.values.firstWhere((s) => s.valeur == v,
          orElse: () => StatutTrajet.planifie);
}

/// Trajet proposé par un transporteur (table "trajet_transport").
/// Les places libres = places totales − places des réservations non annulées.
class TrajetTransport {
  final int? id;
  final int transporteurId;

  /// Jointure : nom du transporteur.
  final String nomTransporteur;
  final String villeDepart;
  final String destination;
  final String adresseDepart;
  final String adresseArrivee;
  final DateTime dateDepart;
  final DateTime dateArriveeEstimee;
  final double prixParPersonne;
  final int placesTotales;

  /// Jointure : places des réservations confirmées ou en cours de prise en charge.
  final int placesReservees;
  final String typeTransport;
  final String arrets;
  final StatutTrajet statut;
  final DateTime creeLe;

  const TrajetTransport({
    this.id,
    required this.transporteurId,
    this.nomTransporteur = '',
    required this.villeDepart,
    required this.destination,
    this.adresseDepart = '',
    this.adresseArrivee = '',
    required this.dateDepart,
    required this.dateArriveeEstimee,
    required this.prixParPersonne,
    required this.placesTotales,
    this.placesReservees = 0,
    required this.typeTransport,
    this.arrets = '',
    this.statut = StatutTrajet.planifie,
    required this.creeLe,
  });

  int get placesLibres {
    final libres = placesTotales - placesReservees;
    return libres < 0 ? 0 : libres;
  }

  bool get complet => placesLibres == 0;

  factory TrajetTransport.fromMap(Map<String, dynamic> m) => TrajetTransport(
        id: m['id'] as int?,
        transporteurId: m['transporteur_id'] as int,
        nomTransporteur: (m['nom_transporteur'] as String?) ?? '',
        villeDepart: m['ville_depart'] as String,
        destination: m['destination'] as String,
        adresseDepart: (m['adresse_depart'] as String?) ?? '',
        adresseArrivee: (m['adresse_arrivee'] as String?) ?? '',
        dateDepart: DateTime.parse(m['date_depart'] as String),
        dateArriveeEstimee: DateTime.parse(m['date_arrivee_estimee'] as String),
        prixParPersonne: (m['prix_par_personne'] as num).toDouble(),
        placesTotales: m['places_totales'] as int,
        placesReservees: (m['places_reservees'] as int?) ?? 0,
        typeTransport: m['type_transport'] as String,
        arrets: (m['arrets'] as String?) ?? '',
        statut: StatutTrajet.depuis(m['statut'] as String),
        creeLe: DateTime.parse(m['cree_le'] as String),
      );

  Map<String, dynamic> toMapSaisie() => {
        'ville_depart': villeDepart.trim(),
        'destination': destination.trim(),
        'adresse_depart': adresseDepart.trim(),
        'adresse_arrivee': adresseArrivee.trim(),
        'date_depart': TransportFormat.dateHeureIso(dateDepart),
        'date_arrivee_estimee': TransportFormat.dateHeureIso(dateArriveeEstimee),
        'prix_par_personne': prixParPersonne,
        'places_totales': placesTotales,
        'type_transport': typeTransport,
        'arrets': arrets.trim(),
        'statut': statut.valeur,
      };

  Map<String, dynamic> toMapCreation() => {
        ...toMapSaisie(),
        'transporteur_id': transporteurId,
        'cree_le': creeLe.toUtc().toIso8601String(),
      };
}
