import 'hebergement.dart';

/// Critères de recherche des établissements (panneau de filtres et assistant IA).
/// Tous facultatifs ; null = pas de filtre.
class FiltresHebergement {
  final TypeHebergement? type;
  final String? recherche;
  final double? prixMin;
  final double? prixMax;
  final int? etoilesMin;
  final double? noteMin;
  final int? personnes;
  final Set<Equipement> equipements;

  /// Au moins une chambre libre pour ces nuits (arrivée, départ).
  final DateTime? arrivee;
  final DateTime? depart;

  /// Position de référence (« proche de moi ») pour le tri par distance.
  final double? latitudeRef;
  final double? longitudeRef;

  const FiltresHebergement({
    this.type,
    this.recherche,
    this.prixMin,
    this.prixMax,
    this.etoilesMin,
    this.noteMin,
    this.personnes,
    this.equipements = const {},
    this.arrivee,
    this.depart,
    this.latitudeRef,
    this.longitudeRef,
  });

  bool get aPositionRef => latitudeRef != null && longitudeRef != null;

  bool get aDates => arrivee != null && depart != null && depart!.isAfter(arrivee!);

  /// Nombre de critères avancés actifs (badge du bouton « Filtres »).
  int get nombreActifs => [
        prixMin != null || prixMax != null,
        etoilesMin != null,
        noteMin != null,
        personnes != null,
        aDates,
      ].where((x) => x).length;

  FiltresHebergement copyWith({
    TypeHebergement? type,
    bool effacerType = false,
    String? recherche,
    double? prixMin,
    double? prixMax,
    bool effacerPrix = false,
    int? etoilesMin,
    bool effacerEtoiles = false,
    double? noteMin,
    bool effacerNote = false,
    int? personnes,
    bool effacerPersonnes = false,
    Set<Equipement>? equipements,
    DateTime? arrivee,
    DateTime? depart,
    bool effacerDates = false,
    double? latitudeRef,
    double? longitudeRef,
  }) =>
      FiltresHebergement(
        type: effacerType ? null : (type ?? this.type),
        recherche: recherche ?? this.recherche,
        prixMin: effacerPrix ? null : (prixMin ?? this.prixMin),
        prixMax: effacerPrix ? null : (prixMax ?? this.prixMax),
        etoilesMin: effacerEtoiles ? null : (etoilesMin ?? this.etoilesMin),
        noteMin: effacerNote ? null : (noteMin ?? this.noteMin),
        personnes: effacerPersonnes ? null : (personnes ?? this.personnes),
        equipements: equipements ?? this.equipements,
        arrivee: effacerDates ? null : (arrivee ?? this.arrivee),
        depart: effacerDates ? null : (depart ?? this.depart),
        latitudeRef: latitudeRef ?? this.latitudeRef,
        longitudeRef: longitudeRef ?? this.longitudeRef,
      );

  /// Critères avancés remis à zéro (type, recherche, équipements et position conservés).
  FiltresHebergement reinitialises() => FiltresHebergement(
        type: type,
        recherche: recherche,
        equipements: equipements,
        latitudeRef: latitudeRef,
        longitudeRef: longitudeRef,
      );
}
