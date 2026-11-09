/// Véhicule à louer (table "vehicule").
class Vehicule {
  final int? id;
  final String marque;
  final String modele;
  final double prixParJour;
  final bool disponible;

  const Vehicule({
    this.id,
    required this.marque,
    required this.modele,
    required this.prixParJour,
    this.disponible = true,
  });

  String get nom => '$marque $modele';

  factory Vehicule.fromMap(Map<String, Object?> m) => Vehicule(
        id: m['id'] as int?,
        marque: m['marque'] as String,
        modele: m['modele'] as String,
        prixParJour: (m['prix_par_jour'] as num).toDouble(),
        disponible: (m['disponible'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        'marque': marque.trim(),
        'modele': modele.trim(),
        'prix_par_jour': prixParJour,
        'disponible': disponible ? 1 : 0,
      };
}
