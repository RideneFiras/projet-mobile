/// Statut d'une mise en relation (colonne "statut").
enum StatutRelation {
  proposee('proposee', 'En attente'),
  acceptee('acceptee', 'Acceptée'),
  refusee('refusee', 'Refusée');

  const StatutRelation(this.valeur, this.libelle);
  final String valeur;
  final String libelle;

  static StatutRelation depuis(String v) =>
      StatutRelation.values.firstWhere((s) => s.valeur == v,
          orElse: () => StatutRelation.proposee);
}

/// Commande proposée automatiquement à un transporteur (table "mise_en_relation") :
/// le transporteur dont un trajet correspond reçoit la proposition, il accepte ou refuse.
/// Le téléphone du voyageur n'est renseigné qu'après acceptation.
class MiseEnRelation {
  final int? id;
  final int commandeId;
  final int trajetId;
  final int transporteurId;
  final StatutRelation statut;
  final DateTime creeLe;
  final DateTime? repondueLe;

  // Jointures : commande, voyageur, trajet
  final String reference;
  final String nomVoyageur;
  final String telephoneVoyageur;
  final int nombrePassagers;
  final double prixPropose;
  final String depart;
  final String arrivee;
  final DateTime dateVoyage;
  final DateTime dateDepart;
  final double prixParPersonne;
  final int placesLibres;
  final String nomTransporteur;

  const MiseEnRelation({
    this.id,
    required this.commandeId,
    required this.trajetId,
    required this.transporteurId,
    this.statut = StatutRelation.proposee,
    required this.creeLe,
    this.repondueLe,
    this.reference = '',
    this.nomVoyageur = '',
    this.telephoneVoyageur = '',
    this.nombrePassagers = 1,
    this.prixPropose = 0,
    this.depart = '',
    this.arrivee = '',
    required this.dateVoyage,
    required this.dateDepart,
    this.prixParPersonne = 0,
    this.placesLibres = 0,
    this.nomTransporteur = '',
  });

  bool get acceptee => statut == StatutRelation.acceptee;
  bool get enAttente => statut == StatutRelation.proposee;

  factory MiseEnRelation.fromMap(Map<String, dynamic> m) => MiseEnRelation(
        id: m['id'] as int?,
        commandeId: m['commande_id'] as int,
        trajetId: m['trajet_id'] as int,
        transporteurId: m['transporteur_id'] as int,
        statut: StatutRelation.depuis(m['statut'] as String),
        creeLe: DateTime.parse(m['cree_le'] as String),
        repondueLe: m['repondu_le'] == null
            ? null
            : DateTime.parse(m['repondu_le'] as String),
        reference: (m['reference'] as String?) ?? '',
        nomVoyageur: (m['nom_voyageur'] as String?) ?? '',
        telephoneVoyageur: (m['telephone_voyageur'] as String?) ?? '',
        nombrePassagers: (m['nombre_passagers'] as int?) ?? 1,
        prixPropose: ((m['prix_propose'] as num?) ?? 0).toDouble(),
        depart: (m['depart'] as String?) ?? '',
        arrivee: (m['arrivee'] as String?) ?? '',
        dateVoyage: DateTime.parse(m['date_voyage'] as String),
        dateDepart: DateTime.parse(m['date_depart'] as String),
        prixParPersonne: ((m['prix_par_personne'] as num?) ?? 0).toDouble(),
        placesLibres: (m['places_libres'] as int?) ?? 0,
        nomTransporteur: (m['nom_transporteur'] as String?) ?? '',
      );
}
