/// Statut d'une commande client (colonne "statut").
enum StatutCommande {
  ouverte('ouverte', 'Ouverte'),
  acceptee('acceptee', 'Acceptée'),
  annulee('annulee', 'Annulée');

  const StatutCommande(this.valeur, this.libelle);
  final String valeur;
  final String libelle;

  static StatutCommande depuis(String v) =>
      StatutCommande.values.firstWhere((s) => s.valeur == v,
          orElse: () => StatutCommande.ouverte);
}

/// Commande passée par un client (table "commande_transport").
/// Les champs "client…" et "voyageur…" viennent d'une jointure avec "utilisateur".
class CommandeTransport {
  final int? id;
  final int clientId;
  final String depart;
  final String arrivee;
  final DateTime dateSouhaitee;
  final double budget;
  final String description;
  final StatutCommande statut;
  final int? voyageurId;
  final DateTime creeLe;

  final String? nomClient;
  final String? contactClient;
  final String? nomVoyageur;
  final String? contactVoyageur;

  const CommandeTransport({
    this.id,
    required this.clientId,
    required this.depart,
    required this.arrivee,
    required this.dateSouhaitee,
    required this.budget,
    this.description = '',
    this.statut = StatutCommande.ouverte,
    this.voyageurId,
    required this.creeLe,
    this.nomClient,
    this.contactClient,
    this.nomVoyageur,
    this.contactVoyageur,
  });

  factory CommandeTransport.fromMap(Map<String, dynamic> m) => CommandeTransport(
        id: m['id'] as int?,
        clientId: m['client_id'] as int,
        depart: m['depart'] as String,
        arrivee: m['arrivee'] as String,
        dateSouhaitee: DateTime.parse(m['date_souhaitee'] as String),
        budget: (m['budget'] as num).toDouble(),
        description: (m['description'] as String?) ?? '',
        statut: StatutCommande.depuis(m['statut'] as String),
        voyageurId: m['voyageur_id'] as int?,
        creeLe: DateTime.parse(m['cree_le'] as String),
        nomClient: m['nom_client'] as String?,
        contactClient: m['contact_client'] as String?,
        nomVoyageur: m['nom_voyageur'] as String?,
        contactVoyageur: m['contact_voyageur'] as String?,
      );

  /// Colonnes modifiables uniquement (le client, la date de création et
  /// le voyageur ne se modifient pas depuis le formulaire).
  Map<String, dynamic> toMapSaisie() => {
        'depart': depart.trim(),
        'arrivee': arrivee.trim(),
        'date_souhaitee':
            DateTime(dateSouhaitee.year, dateSouhaitee.month, dateSouhaitee.day)
                .toIso8601String()
                .substring(0, 10),
        'budget': budget,
        'description': description.trim(),
      };

  Map<String, dynamic> toMapCreation() => {
        ...toMapSaisie(),
        'client_id': clientId,
        'statut': StatutCommande.ouverte.valeur,
        'cree_le': creeLe.toUtc().toIso8601String(),
      };
}
