/// Établissement d'hébergement (table "hebergement").
class Hebergement {
  static const List<String> types = [
    'Hôtel',
    'Auberge',
    'Appartement',
    "Maison d'hôtes",
  ];

  final int? id;
  final String nom;
  final String type;
  final String adresse;
  final double prixParNuit;

  const Hebergement({
    this.id,
    required this.nom,
    required this.type,
    required this.adresse,
    required this.prixParNuit,
  });

  factory Hebergement.fromMap(Map<String, Object?> m) => Hebergement(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        type: m['type'] as String,
        adresse: m['adresse'] as String,
        prixParNuit: (m['prix_par_nuit'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'nom': nom.trim(),
        'type': type,
        'adresse': adresse.trim(),
        'prix_par_nuit': prixParNuit,
      };
}
