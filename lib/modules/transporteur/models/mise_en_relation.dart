/// Statut d'une proposition de voyageur (colonne "statut").
enum StatutRelation {
  proposee('proposee', 'En attente de réponse'),
  acceptee('acceptee', 'Acceptée'),
  refusee('refusee', 'Refusée');

  const StatutRelation(this.valeur, this.libelle);
  final String valeur;
  final String libelle;

  static StatutRelation depuis(String v) =>
      StatutRelation.values.firstWhere((s) => s.valeur == v,
          orElse: () => StatutRelation.proposee);
}

/// Proposition d'un voyageur pour une commande (table "mise_en_relation").
/// Créée par un transporteur, acceptée ou refusée par le voyageur.
/// Les coordonnées sont visibles des deux côtés seulement si statut = acceptee.
class MiseEnRelation {
  final int? id;
  final int commandeId;
  final int auteurId;
  final int voyageurId;
  final int? transporteurId;
  final StatutRelation statut;
  final DateTime creeLe;

  final String? nomVoyageur;
  final String? contactVoyageur;
  final String? nomClient;
  final String? contactClient;
  final String? nomTransporteur;
  final String? trajet;
  final double? budget;

  const MiseEnRelation({
    this.id,
    required this.commandeId,
    required this.auteurId,
    required this.voyageurId,
    this.transporteurId,
    this.statut = StatutRelation.proposee,
    required this.creeLe,
    this.nomVoyageur,
    this.contactVoyageur,
    this.nomClient,
    this.contactClient,
    this.nomTransporteur,
    this.trajet,
    this.budget,
  });

  bool get acceptee => statut == StatutRelation.acceptee;

  factory MiseEnRelation.fromMap(Map<String, dynamic> m) => MiseEnRelation(
        id: m['id'] as int?,
        commandeId: m['commande_id'] as int,
        auteurId: m['auteur_id'] as int,
        voyageurId: m['voyageur_id'] as int,
        transporteurId: m['transporteur_id'] as int?,
        statut: StatutRelation.depuis(m['statut'] as String),
        creeLe: DateTime.parse(m['cree_le'] as String),
        nomVoyageur: m['nom_voyageur'] as String?,
        contactVoyageur: m['contact_voyageur'] as String?,
        nomClient: m['nom_client'] as String?,
        contactClient: m['contact_client'] as String?,
        nomTransporteur: m['nom_transporteur'] as String?,
        trajet: m['trajet'] as String?,
        budget: (m['budget'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMapCreation() => {
        'commande_id': commandeId,
        'auteur_id': auteurId,
        'voyageur_id': voyageurId,
        'transporteur_id': transporteurId,
        'statut': StatutRelation.proposee.valeur,
        'cree_le': creeLe.toUtc().toIso8601String(),
      };
}
