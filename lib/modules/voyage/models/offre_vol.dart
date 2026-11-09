import '../../../core/utils/dates.dart';

/// Classe de voyage. Le prix final = prix de base × coefficient.
enum ClasseVol {
  eco('eco', 'Économique', 1.0),
  affaires('affaires', 'Affaires', 2.2),
  premiere('premiere', 'Première', 3.5);

  const ClasseVol(this.valeur, this.libelle, this.coefficient);

  final String valeur;
  final String libelle;
  final double coefficient;

  static ClasseVol depuis(String valeur) => ClasseVol.values
      .firstWhere((c) => c.valeur == valeur, orElse: () => ClasseVol.eco);
}

/// Une offre du catalogue : une ville, un aller-retour et un prix de base (DT).
class OffreVol {
  final int? id;
  final String ville;
  final String pays;
  final double latitude;
  final double longitude;
  final int dureeMinutes;
  final DateTime dateDepart;
  final DateTime dateRetour;
  final double prixBase;

  const OffreVol({
    this.id,
    required this.ville,
    required this.pays,
    required this.latitude,
    required this.longitude,
    required this.dureeMinutes,
    required this.dateDepart,
    required this.dateRetour,
    required this.prixBase,
  });

  /// Prix selon la classe, arrondi au centime. C'est le SEUL endroit où il se calcule.
  double prixPour(ClasseVol classe) =>
      (prixBase * classe.coefficient * 100).round() / 100;

  /// Durée du vol, ex : « 1h30 ».
  String get dureeLibelle {
    final h = dureeMinutes ~/ 60;
    final m = dureeMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }

  /// Nombre de nuits sur place.
  int get nuits => nombreDeJours(dateDepart, dateRetour);

  factory OffreVol.fromMap(Map<String, Object?> m) => OffreVol(
    id: m['id'] as int?,
    ville: m['ville'] as String,
    pays: m['pays'] as String,
    latitude: (m['latitude'] as num).toDouble(),
    longitude: (m['longitude'] as num).toDouble(),
    dureeMinutes: m['duree_minutes'] as int,
    dateDepart: DateTime.parse(m['date_depart'] as String),
    dateRetour: DateTime.parse(m['date_retour'] as String),
    prixBase: (m['prix_base'] as num).toDouble(),
  );

  Map<String, Object?> toMap() => {
    'ville': ville,
    'pays': pays,
    'latitude': latitude,
    'longitude': longitude,
    'duree_minutes': dureeMinutes,
    'date_depart': dateIso(dateDepart),
    'date_retour': dateIso(dateRetour),
    'prix_base': prixBase,
  };
}
