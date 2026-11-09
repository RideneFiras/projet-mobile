import '../transport_format.dart';

/// Statut d'une commande (colonne "statut"), valeurs du cahier des charges.
enum StatutCommande {
  enAttente('EN_ATTENTE', 'En attente'),
  acceptee('ACCEPTEE', 'Acceptée'),
  refusee('REFUSEE', 'Refusée'),
  annulee('ANNULEE', 'Annulée'),
  termine('termine', 'Terminée');

  const StatutCommande(this.valeur, this.libelle);
  final String valeur;
  final String libelle;

  static StatutCommande depuis(String v) =>
      StatutCommande.values.firstWhere((s) => s.valeur == v,
          orElse: () => StatutCommande.enAttente);
}

/// Demande de transport d'un voyageur (table "commande_transport").
/// Les champs de jointure ne sont pas saisis : ils viennent de la base.
class CommandeTransport {
  final int? id;
  final String reference;
  final int voyageurId;
  final String depart;
  final String arrivee;
  final DateTime dateVoyage;
  final int nombrePassagers;

  /// Budget du voyageur, en dinars. 0 = pas de budget.
  final double prixPropose;
  final String commentaire;
  final StatutCommande statut;
  final DateTime creeLe;

  // Jointures
  final String nomVoyageur;
  final int nbPropositions;

  /// Renseignés seulement une fois la commande acceptée.
  final String nomTransporteur;
  final String telephoneTransporteur;
  final int? reservationId;

  const CommandeTransport({
    this.id,
    this.reference = '',
    required this.voyageurId,
    required this.depart,
    required this.arrivee,
    required this.dateVoyage,
    this.nombrePassagers = 1,
    this.prixPropose = 0,
    this.commentaire = '',
    this.statut = StatutCommande.enAttente,
    required this.creeLe,
    this.nomVoyageur = '',
    this.nbPropositions = 0,
    this.nomTransporteur = '',
    this.telephoneTransporteur = '',
    this.reservationId,
  });

  /// Modifiable seulement tant que personne n'a accepté.
  bool get modifiable => statut == StatutCommande.enAttente;

  /// Annulable : libre en attente, sous conditions une fois acceptée.
  bool get annulable =>
      statut == StatutCommande.enAttente || statut == StatutCommande.acceptee;

  bool get acceptee =>
      statut == StatutCommande.acceptee || statut == StatutCommande.termine;

  factory CommandeTransport.fromMap(Map<String, dynamic> m) => CommandeTransport(
        id: m['id'] as int?,
        reference: m['reference'] as String,
        voyageurId: m['voyageur_id'] as int,
        depart: m['depart'] as String,
        arrivee: m['arrivee'] as String,
        dateVoyage: DateTime.parse(m['date_voyage'] as String),
        nombrePassagers: m['nombre_passagers'] as int,
        prixPropose: (m['prix_propose'] as num).toDouble(),
        commentaire: (m['commentaire'] as String?) ?? '',
        statut: StatutCommande.depuis(m['statut'] as String),
        creeLe: DateTime.parse(m['cree_le'] as String),
        nomVoyageur: (m['nom_voyageur'] as String?) ?? '',
        nbPropositions: (m['nb_propositions'] as int?) ?? 0,
        nomTransporteur: (m['nom_transporteur'] as String?) ?? '',
        telephoneTransporteur: (m['telephone_transporteur'] as String?) ?? '',
        reservationId: m['reservation_id'] as int?,
      );

  /// Colonnes saisies. La référence, le voyageur et le statut ne se modifient pas ici.
  Map<String, dynamic> toMapSaisie() => {
        'depart': depart.trim(),
        'arrivee': arrivee.trim(),
        'date_voyage': TransportFormat.dateHeureIso(dateVoyage),
        'nombre_passagers': nombrePassagers,
        'prix_propose': prixPropose,
        'commentaire': commentaire.trim(),
      };

  Map<String, dynamic> toMapCreation() => {
        ...toMapSaisie(),
        'voyageur_id': voyageurId,
        'statut': StatutCommande.enAttente.valeur,
        'cree_le': creeLe.toUtc().toIso8601String(),
      };
}
