import 'vehicule.dart';

/// Ordre d'affichage de la liste des véhicules.
enum TriVehicule {
  nom('nom', 'Nom'),
  prixCroissant('prix_croissant', 'Prix croissant'),
  prixDecroissant('prix_decroissant', 'Prix décroissant'),
  popularite('popularite', 'Les plus loués'),
  distance('distance', 'Les plus proches');

  const TriVehicule(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static TriVehicule depuis(String? valeur) =>
      TriVehicule.values.firstWhere((t) => t.valeur == valeur, orElse: () => TriVehicule.nom);
}

/// Critères de recherche des véhicules (écran de filtres et assistant IA).
/// Tous les critères sont facultatifs ; null = pas de filtre.
class FiltresVehicule {
  final TypeVehicule? type;
  final String? recherche;
  final double? prixMin;
  final double? prixMax;
  final int? anneeMin;
  final Carburant? carburant;
  final Boite? boite;
  final int? placesMin;

  /// Disponible sur toute la période (aucune location ni blocage).
  final DateTime? disponibleDu;
  final DateTime? disponibleAu;
  final TriVehicule tri;

  /// Position de référence pour le tri par distance.
  final double? latitudeRef;
  final double? longitudeRef;

  const FiltresVehicule({
    this.type,
    this.recherche,
    this.prixMin,
    this.prixMax,
    this.anneeMin,
    this.carburant,
    this.boite,
    this.placesMin,
    this.disponibleDu,
    this.disponibleAu,
    this.tri = TriVehicule.nom,
    this.latitudeRef,
    this.longitudeRef,
  });

  /// Nombre de critères actifs (badge du bouton « Filtres »), hors type et recherche.
  int get nombreActifs => [
        prixMin != null || prixMax != null,
        anneeMin != null,
        carburant != null,
        boite != null,
        placesMin != null,
        disponibleDu != null && disponibleAu != null,
      ].where((x) => x).length;

  bool get aPositionRef => latitudeRef != null && longitudeRef != null;

  /// Copie : les paramètres « effacer… » remettent un critère à null.
  FiltresVehicule copyWith({
    TypeVehicule? type,
    bool effacerType = false,
    String? recherche,
    double? prixMin,
    double? prixMax,
    bool effacerPrix = false,
    int? anneeMin,
    bool effacerAnnee = false,
    Carburant? carburant,
    bool effacerCarburant = false,
    Boite? boite,
    bool effacerBoite = false,
    int? placesMin,
    bool effacerPlaces = false,
    DateTime? disponibleDu,
    DateTime? disponibleAu,
    bool effacerDates = false,
    TriVehicule? tri,
    double? latitudeRef,
    double? longitudeRef,
  }) =>
      FiltresVehicule(
        type: effacerType ? null : (type ?? this.type),
        recherche: recherche ?? this.recherche,
        prixMin: effacerPrix ? null : (prixMin ?? this.prixMin),
        prixMax: effacerPrix ? null : (prixMax ?? this.prixMax),
        anneeMin: effacerAnnee ? null : (anneeMin ?? this.anneeMin),
        carburant: effacerCarburant ? null : (carburant ?? this.carburant),
        boite: effacerBoite ? null : (boite ?? this.boite),
        placesMin: effacerPlaces ? null : (placesMin ?? this.placesMin),
        disponibleDu: effacerDates ? null : (disponibleDu ?? this.disponibleDu),
        disponibleAu: effacerDates ? null : (disponibleAu ?? this.disponibleAu),
        tri: tri ?? this.tri,
        latitudeRef: latitudeRef ?? this.latitudeRef,
        longitudeRef: longitudeRef ?? this.longitudeRef,
      );

  /// Critères « avancés » remis à zéro (type, recherche, tri et position conservés).
  FiltresVehicule reinitialises() => FiltresVehicule(
        type: type,
        recherche: recherche,
        tri: tri,
        latitudeRef: latitudeRef,
        longitudeRef: longitudeRef,
      );
}
