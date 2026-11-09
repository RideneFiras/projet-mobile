/// Un voyage déclaré par un voyageur (lu dans la table "voyage").
class VoyageTrajet {
  final String destination;
  final DateTime dateDebut;
  final DateTime dateFin;

  const VoyageTrajet({
    required this.destination,
    required this.dateDebut,
    required this.dateFin,
  });
}

/// Voyageur pouvant accepter une commande, avec la liste de ses voyages.
class VoyageurCandidat {
  final int id;
  final String nom;
  final List<VoyageTrajet> voyages;

  const VoyageurCandidat({
    required this.id,
    required this.nom,
    required this.voyages,
  });
}
