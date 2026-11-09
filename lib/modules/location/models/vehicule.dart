import 'package:flutter/material.dart';

import '../../../core/utils/json_listes.dart';
import '../../../core/utils/tarification.dart';

/// Type de véhicule. "valeur" = ce qui est stocké en base.
enum TypeVehicule {
  voiture('voiture', 'Voiture', Icons.directions_car, 5),
  moto('moto', 'Moto', Icons.two_wheeler, 2),
  bicyclette('bicyclette', 'Bicyclette', Icons.pedal_bike, 1);

  const TypeVehicule(this.valeur, this.libelle, this.icone, this.placesParDefaut);

  final String valeur;
  final String libelle;
  final IconData icone;
  final int placesParDefaut;

  /// Voiture et moto : moteur, immatriculation obligatoire.
  bool get motorise => this != bicyclette;

  /// Nombre de places autorisé pour ce type.
  (int, int) get bornesPlaces => switch (this) {
        voiture => (2, 9),
        moto => (1, 2),
        bicyclette => (1, 2),
      };

  /// Carburants proposés dans le formulaire pour ce type.
  List<Carburant> get carburants => switch (this) {
        voiture => const [
            Carburant.essence,
            Carburant.diesel,
            Carburant.hybride,
            Carburant.electrique,
          ],
        moto => const [Carburant.essence, Carburant.electrique],
        bicyclette => const [Carburant.aucun, Carburant.electrique],
      };

  static TypeVehicule depuis(String? valeur) => TypeVehicule.values
      .firstWhere((t) => t.valeur == valeur, orElse: () => TypeVehicule.voiture);
}

enum Carburant {
  essence('essence', 'Essence'),
  diesel('diesel', 'Diesel'),
  electrique('electrique', 'Électrique'),
  hybride('hybride', 'Hybride'),
  aucun('aucun', 'Musculaire');

  const Carburant(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static Carburant depuis(String? valeur) => Carburant.values
      .firstWhere((c) => c.valeur == valeur, orElse: () => Carburant.essence);
}

enum Boite {
  manuelle('manuelle', 'Manuelle'),
  automatique('automatique', 'Automatique');

  const Boite(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static Boite? depuis(String? valeur) {
    for (final b in Boite.values) {
      if (b.valeur == valeur) return b;
    }
    return null;
  }
}

/// Statut du véhicule dans la flotte (« loué » se calcule à partir des locations).
enum StatutVehicule {
  disponible('disponible', 'Disponible'),
  maintenance('maintenance', 'En maintenance'),
  horsService('hors_service', 'Hors service');

  const StatutVehicule(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static StatutVehicule depuis(String? valeur) => StatutVehicule.values.firstWhere(
      (s) => s.valeur == valeur,
      orElse: () => StatutVehicule.disponible);
}

/// Véhicule à louer (table "vehicule") : voiture, moto ou bicyclette.
class Vehicule {
  final int? id;
  final TypeVehicule type;
  final String marque;
  final String modele;
  final int? annee;
  final String? couleur;
  final String? immatriculation;
  final Carburant carburant;
  final Boite? boite;
  final int places;

  /// Compteur kilométrique actuel (voiture, moto) ; null pour une bicyclette.
  /// Mis à jour à la clôture de chaque location.
  final int? kilometrage;

  /// Entretien : compteur à la dernière révision et intervalle entre deux révisions.
  final int? kmDerniereRevision;
  final int intervalleRevision;
  final double prixParJour;

  /// Tarification dynamique, en pourcentages (0 = prix fixe).
  final double majorationWeekend;
  final double majorationSaison;
  final double remiseLongueDuree;

  /// Propriétaire (multi-propriétaires) ; null = véhicule de l'agence.
  final int? proprietaireId;
  final double caution;
  final List<String> photos;
  final double? latitude;
  final double? longitude;
  final String? adresse;
  final String? description;
  final StatutVehicule statut;
  final DateTime? creeLe;

  /// Champs calculés par le repository (absents à la saisie).
  final bool enLocation;
  final double noteMoyenne;
  final int nbAvis;

  /// Nombre de locations non annulées (popularité).
  final int nbLocations;

  const Vehicule({
    this.id,
    this.type = TypeVehicule.voiture,
    required this.marque,
    required this.modele,
    this.annee,
    this.couleur,
    this.immatriculation,
    this.carburant = Carburant.essence,
    this.boite,
    int? places,
    this.kilometrage,
    this.kmDerniereRevision,
    this.intervalleRevision = 10000,
    required this.prixParJour,
    this.majorationWeekend = 0,
    this.majorationSaison = 0,
    this.remiseLongueDuree = 0,
    this.proprietaireId,
    this.caution = 0,
    this.photos = const [],
    this.latitude,
    this.longitude,
    this.adresse,
    this.description,
    this.statut = StatutVehicule.disponible,
    this.creeLe,
    this.enLocation = false,
    this.noteMoyenne = 0,
    this.nbAvis = 0,
    this.nbLocations = 0,
  }) : places = places ??
            (type == TypeVehicule.voiture
                ? 5
                : (type == TypeVehicule.moto ? 2 : 1));

  String get nom => '$marque $modele';

  /// Réservable : seul le statut "disponible" accepte de nouvelles locations.
  bool get disponible => statut == StatutVehicule.disponible;

  bool get aPosition => latitude != null && longitude != null;

  /// Motorisation électrique (voiture, moto ou vélo à assistance électrique).
  bool get estElectrique => carburant == Carburant.electrique;

  ReglesTarif get reglesTarif => ReglesTarif(
        majorationWeekend: majorationWeekend,
        majorationSaison: majorationSaison,
        remiseLongueDuree: remiseLongueDuree,
      );

  /// Kilomètres parcourus depuis la dernière révision (null si inconnu).
  int? get kmDepuisRevision => (kilometrage == null || kmDerniereRevision == null)
      ? null
      : kilometrage! - kmDerniereRevision!;

  /// Révision à faire : intervalle atteint.
  bool get revisionDue => (kmDepuisRevision ?? 0) >= intervalleRevision;

  /// Révision bientôt nécessaire (90 % de l'intervalle).
  bool get revisionProche => !revisionDue && (kmDepuisRevision ?? 0) >= intervalleRevision * 0.9;

  String? get photoPrincipale => photos.isEmpty ? null : photos.first;

  /// « 2022 · Blanc · Diesel · Manuelle · 5 places »
  String get resumeTechnique => [
        if (annee != null) '$annee',
        if (couleur != null && couleur!.isNotEmpty) couleur!,
        carburant.libelle,
        if (boite != null) boite!.libelle,
        '$places place${places > 1 ? 's' : ''}',
      ].join(' · ');

  /// Règles métier, vérifiées avant toute écriture. Renvoie un message ou null.
  String? verifier() {
    if (marque.trim().isEmpty || modele.trim().isEmpty) {
      return 'Marque et modèle obligatoires';
    }
    if (prixParJour < 0 || caution < 0) return 'Les montants doivent être positifs';
    final anneeMax = DateTime.now().year + 1;
    if (annee != null && (annee! < 1950 || annee! > anneeMax)) {
      return 'Année entre 1950 et $anneeMax';
    }
    final (minPlaces, maxPlaces) = type.bornesPlaces;
    if (places < minPlaces || places > maxPlaces) {
      return '${type.libelle} : entre $minPlaces et $maxPlaces places';
    }
    if (kilometrage != null) {
      if (!type.motorise) return 'Une bicyclette n\'a pas de compteur kilométrique';
      if (kilometrage! < 0) return 'Kilométrage invalide';
    }
    if (intervalleRevision < 500 || intervalleRevision > 100000) {
      return 'Intervalle de révision entre 500 et 100 000 km';
    }
    if (kmDerniereRevision != null && kilometrage != null && kmDerniereRevision! > kilometrage!) {
      return 'La dernière révision ne peut pas dépasser le kilométrage actuel';
    }
    final tarif = reglesTarif.verifier();
    if (tarif != null) return tarif;
    if (!type.carburants.contains(carburant)) {
      return '${type.libelle} : motorisation « ${carburant.libelle} » impossible';
    }
    final immat = immatriculation?.trim() ?? '';
    if (type.motorise) {
      if (immat.isEmpty) return 'Immatriculation obligatoire pour une ${type.libelle.toLowerCase()}';
      if (!RegExp(r'^[A-Z0-9 \-]{4,15}$').hasMatch(immat.toUpperCase())) {
        return 'Immatriculation invalide (ex : 215 TU 4587)';
      }
    } else {
      if (immat.isNotEmpty) return 'Une bicyclette n\'a pas d\'immatriculation';
      if (boite != null) return 'Une bicyclette n\'a pas de boîte de vitesses';
    }
    if (type == TypeVehicule.moto && boite == null) {
      return 'Précisez la boîte de vitesses de la moto';
    }
    if ((latitude == null) != (longitude == null)) {
      return 'Latitude et longitude vont ensemble';
    }
    if (latitude != null && (latitude! < -90 || latitude! > 90)) return 'Latitude invalide';
    if (longitude != null && (longitude! < -180 || longitude! > 180)) {
      return 'Longitude invalide';
    }
    return null;
  }

  factory Vehicule.fromMap(Map<String, Object?> m) {
    final type = TypeVehicule.depuis(m['type'] as String?);
    return Vehicule(
      id: m['id'] as int?,
      type: type,
      marque: m['marque'] as String,
      modele: m['modele'] as String,
      annee: m['annee'] as int?,
      couleur: m['couleur'] as String?,
      immatriculation: m['immatriculation'] as String?,
      carburant: Carburant.depuis(m['carburant'] as String?),
      boite: Boite.depuis(m['boite'] as String?),
      places: (m['places'] as int?) ?? type.placesParDefaut,
      kilometrage: m['kilometrage'] as int?,
      kmDerniereRevision: m['km_derniere_revision'] as int?,
      intervalleRevision: (m['intervalle_revision'] as int?) ?? 10000,
      majorationWeekend: ((m['majoration_weekend'] as num?) ?? 0).toDouble(),
      majorationSaison: ((m['majoration_saison'] as num?) ?? 0).toDouble(),
      remiseLongueDuree: ((m['remise_longue_duree'] as num?) ?? 0).toDouble(),
      proprietaireId: m['proprietaire_id'] as int?,
      prixParJour: (m['prix_par_jour'] as num).toDouble(),
      caution: ((m['caution'] as num?) ?? 0).toDouble(),
      photos: listeDepuisJson(m['photos']),
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      adresse: m['adresse'] as String?,
      description: m['description'] as String?,
      statut: StatutVehicule.depuis(m['statut'] as String?),
      creeLe: DateTime.tryParse((m['cree_le'] as String?) ?? ''),
      enLocation: (m['en_location'] as int? ?? 0) == 1,
      noteMoyenne: ((m['note_moyenne'] as num?) ?? 0).toDouble(),
      nbAvis: (m['nb_avis'] as int?) ?? 0,
      nbLocations: (m['nb_locations'] as int?) ?? 0,
    );
  }

  /// Une bicyclette n'enregistre ni immatriculation ni boîte.
  Map<String, Object?> toMap() {
    String? texte(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    return {
      'type': type.valeur,
      'marque': marque.trim(),
      'modele': modele.trim(),
      'annee': annee,
      'couleur': texte(couleur),
      'immatriculation': type.motorise ? texte(immatriculation)?.toUpperCase() : null,
      'carburant': carburant.valeur,
      'boite': type.motorise ? boite?.valeur : null,
      'places': places,
      'kilometrage': type.motorise ? kilometrage : null,
      'km_derniere_revision': type.motorise ? (kmDerniereRevision ?? kilometrage) : null,
      'intervalle_revision': intervalleRevision,
      'prix_par_jour': prixParJour,
      'majoration_weekend': majorationWeekend,
      'majoration_saison': majorationSaison,
      'remise_longue_duree': remiseLongueDuree,
      'proprietaire_id': proprietaireId,
      'caution': caution,
      'photos': listeEnJson(photos),
      'latitude': latitude,
      'longitude': longitude,
      'adresse': texte(adresse),
      'description': texte(description),
      'statut': statut.valeur,
      'cree_le': (creeLe ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  Vehicule copyWith({
    TypeVehicule? type,
    String? marque,
    String? modele,
    int? annee,
    String? couleur,
    String? immatriculation,
    Carburant? carburant,
    Boite? boite,
    int? places,
    int? kilometrage,
    int? kmDerniereRevision,
    int? intervalleRevision,
    double? prixParJour,
    double? majorationWeekend,
    double? majorationSaison,
    double? remiseLongueDuree,
    double? caution,
    List<String>? photos,
    double? latitude,
    double? longitude,
    String? adresse,
    String? description,
    StatutVehicule? statut,
  }) =>
      Vehicule(
        id: id,
        type: type ?? this.type,
        marque: marque ?? this.marque,
        modele: modele ?? this.modele,
        annee: annee ?? this.annee,
        couleur: couleur ?? this.couleur,
        immatriculation: immatriculation ?? this.immatriculation,
        carburant: carburant ?? this.carburant,
        boite: boite ?? this.boite,
        places: places ?? this.places,
        kilometrage: kilometrage ?? this.kilometrage,
        kmDerniereRevision: kmDerniereRevision ?? this.kmDerniereRevision,
        intervalleRevision: intervalleRevision ?? this.intervalleRevision,
        majorationWeekend: majorationWeekend ?? this.majorationWeekend,
        majorationSaison: majorationSaison ?? this.majorationSaison,
        remiseLongueDuree: remiseLongueDuree ?? this.remiseLongueDuree,
        proprietaireId: proprietaireId,
        prixParJour: prixParJour ?? this.prixParJour,
        caution: caution ?? this.caution,
        photos: photos ?? this.photos,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        adresse: adresse ?? this.adresse,
        description: description ?? this.description,
        statut: statut ?? this.statut,
        creeLe: creeLe,
      );
}
