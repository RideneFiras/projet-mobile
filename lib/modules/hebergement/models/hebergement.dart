import 'package:flutter/material.dart';

import '../../../core/utils/json_listes.dart';
import '../../../core/utils/tarification.dart';

/// Type d'établissement. "valeur" = ce qui est stocké en base.
enum TypeHebergement {
  hotel('hotel', 'Hôtel', Icons.hotel),
  auberge('auberge', 'Auberge', Icons.bed),
  appartement('appartement', 'Appartement', Icons.apartment),
  maisonHotes('maison_hotes', "Maison d'hôtes", Icons.house),
  villa('villa', 'Villa', Icons.villa),
  riad('riad', 'Riad', Icons.holiday_village),
  camping('camping', 'Camping', Icons.cabin);

  const TypeHebergement(this.valeur, this.libelle, this.icone);

  final String valeur;
  final String libelle;
  final IconData icone;

  /// Les étoiles n'ont de sens que pour un hôtel.
  bool get classable => this == hotel;

  /// Accepte aussi les anciens libellés stockés avant la version 2 (« Hôtel »…).
  static TypeHebergement depuis(String? valeur) => TypeHebergement.values.firstWhere(
      (t) => t.valeur == valeur || t.libelle == valeur,
      orElse: () => TypeHebergement.hotel);
}

/// Équipements proposés. Stockés en JSON : ["wifi","piscine"].
enum Equipement {
  wifi('wifi', 'Wi-Fi', Icons.wifi),
  parking('parking', 'Parking', Icons.local_parking),
  piscine('piscine', 'Piscine', Icons.pool),
  climatisation('climatisation', 'Climatisation', Icons.ac_unit),
  petitDejeuner('petit_dejeuner', 'Petit-déjeuner', Icons.free_breakfast),
  restaurant('restaurant', 'Restaurant', Icons.restaurant),
  spa('spa', 'Spa', Icons.spa),
  salleSport('salle_sport', 'Salle de sport', Icons.fitness_center),
  plage('plage', 'Accès plage', Icons.beach_access),
  cuisine('cuisine', 'Cuisine équipée', Icons.kitchen),
  navette('navette', 'Navette aéroport', Icons.airport_shuttle),
  animaux('animaux', 'Animaux acceptés', Icons.pets);

  const Equipement(this.valeur, this.libelle, this.icone);

  final String valeur;
  final String libelle;
  final IconData icone;

  static Equipement? depuis(String valeur) {
    for (final e in Equipement.values) {
      if (e.valeur == valeur) return e;
    }
    return null;
  }
}

enum StatutHebergement {
  actif('actif', 'Ouvert'),
  travaux('travaux', 'En travaux'),
  ferme('ferme', 'Fermé');

  const StatutHebergement(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static StatutHebergement depuis(String? valeur) => StatutHebergement.values
      .firstWhere((s) => s.valeur == valeur, orElse: () => StatutHebergement.actif);
}

/// Établissement d'hébergement (table "hebergement").
class Hebergement {
  final int? id;
  final String nom;
  final TypeHebergement type;
  final String? description;

  /// Règles de la maison (animaux, fêtes, tabac…), texte libre.
  final String? regles;
  final String adresse;
  final String? ville;
  final double? latitude;
  final double? longitude;
  final int? etoiles;
  final double prixParNuit;

  /// Tarification dynamique, en pourcentages (0 = prix fixe).
  final double majorationWeekend;
  final double majorationSaison;
  final double remiseLongueDuree;

  /// Surface du logement en m² (appartement, villa…).
  final double? superficie;

  /// Propriétaire (multi-propriétaires) ; null = établissement géré par l'agence.
  final int? proprietaireId;

  /// Nombre de séjours non annulés (popularité), calculé par le repository.
  final int nbReservations;

  /// Personnes maximum par chambre (ou par logement entier).
  final int capacite;

  /// Nombre de chambres / unités réservables en même temps.
  final int nbChambres;
  final List<Equipement> equipements;
  final List<String> photos;
  final String? telephone;
  final String heureArrivee;
  final String heureDepart;

  /// Recalculés par le repository depuis la table "avis" : jamais saisis.
  final double noteMoyenne;
  final int nbAvis;
  final StatutHebergement statut;
  final DateTime? creeLe;

  const Hebergement({
    this.id,
    required this.nom,
    this.type = TypeHebergement.hotel,
    this.description,
    this.regles,
    required this.adresse,
    this.ville,
    this.latitude,
    this.longitude,
    this.etoiles,
    required this.prixParNuit,
    this.majorationWeekend = 0,
    this.majorationSaison = 0,
    this.remiseLongueDuree = 0,
    this.superficie,
    this.proprietaireId,
    this.nbReservations = 0,
    this.capacite = 2,
    this.nbChambres = 1,
    this.equipements = const [],
    this.photos = const [],
    this.telephone,
    this.heureArrivee = '15:00',
    this.heureDepart = '11:00',
    this.noteMoyenne = 0,
    this.nbAvis = 0,
    this.statut = StatutHebergement.actif,
    this.creeLe,
  });

  bool get ouvert => statut == StatutHebergement.actif;

  bool get aPosition => latitude != null && longitude != null;

  String? get photoPrincipale => photos.isEmpty ? null : photos.first;

  /// « Houmt Souk, Djerba »
  String get adresseComplete =>
      (ville == null || ville!.isEmpty) ? adresse : '$adresse, $ville';

  /// Capacité totale de l'établissement (toutes chambres confondues).
  int get capaciteTotale => capacite * nbChambres;

  bool possede(Equipement e) => equipements.contains(e);

  ReglesTarif get reglesTarif => ReglesTarif(
        majorationWeekend: majorationWeekend,
        majorationSaison: majorationSaison,
        remiseLongueDuree: remiseLongueDuree,
      );

  static final RegExp _heure = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// Règles métier, vérifiées avant toute écriture. Renvoie un message ou null.
  String? verifier() {
    if (nom.trim().isEmpty) return 'Le nom est obligatoire';
    if (adresse.trim().isEmpty) return 'L\'adresse est obligatoire';
    if (prixParNuit < 0) return 'Le prix doit être positif';
    if (etoiles != null) {
      if (!type.classable) return 'Seul un hôtel peut être classé en étoiles';
      if (etoiles! < 1 || etoiles! > 5) return 'Entre 1 et 5 étoiles';
    }
    if (capacite < 1 || capacite > 20) return 'Capacité entre 1 et 20 personnes';
    if (nbChambres < 1 || nbChambres > 500) return 'Entre 1 et 500 chambres';
    if (superficie != null && (superficie! <= 0 || superficie! > 10000)) {
      return 'Superficie invalide';
    }
    final tarif = reglesTarif.verifier();
    if (tarif != null) return tarif;
    if (!_heure.hasMatch(heureArrivee) || !_heure.hasMatch(heureDepart)) {
      return 'Heures au format HH:MM (ex : 15:00)';
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

  factory Hebergement.fromMap(Map<String, Object?> m) => Hebergement(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        type: TypeHebergement.depuis(m['type'] as String?),
        description: m['description'] as String?,
        regles: m['regles'] as String?,
        adresse: m['adresse'] as String,
        ville: m['ville'] as String?,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        etoiles: m['etoiles'] as int?,
        prixParNuit: (m['prix_par_nuit'] as num).toDouble(),
        majorationWeekend: ((m['majoration_weekend'] as num?) ?? 0).toDouble(),
        majorationSaison: ((m['majoration_saison'] as num?) ?? 0).toDouble(),
        remiseLongueDuree: ((m['remise_longue_duree'] as num?) ?? 0).toDouble(),
        superficie: (m['superficie'] as num?)?.toDouble(),
        proprietaireId: m['proprietaire_id'] as int?,
        nbReservations: (m['nb_reservations'] as int?) ?? 0,
        capacite: (m['capacite'] as int?) ?? 2,
        nbChambres: (m['nb_chambres'] as int?) ?? 1,
        equipements: [
          for (final v in listeDepuisJson(m['equipements']))
            if (Equipement.depuis(v) case final e?) e,
        ],
        photos: listeDepuisJson(m['photos']),
        telephone: m['telephone'] as String?,
        heureArrivee: (m['heure_arrivee'] as String?) ?? '15:00',
        heureDepart: (m['heure_depart'] as String?) ?? '11:00',
        noteMoyenne: ((m['note_moyenne'] as num?) ?? 0).toDouble(),
        nbAvis: (m['nb_avis'] as int?) ?? 0,
        statut: StatutHebergement.depuis(m['statut'] as String?),
        creeLe: DateTime.tryParse((m['cree_le'] as String?) ?? ''),
      );

  /// note_moyenne et nb_avis ne sont pas écrits : le repository les recalcule.
  Map<String, Object?> toMap() {
    String? texte(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    return {
      'nom': nom.trim(),
      'type': type.valeur,
      'description': texte(description),
      'regles': texte(regles),
      'adresse': adresse.trim(),
      'ville': texte(ville),
      'latitude': latitude,
      'longitude': longitude,
      'etoiles': type.classable ? etoiles : null,
      'prix_par_nuit': prixParNuit,
      'majoration_weekend': majorationWeekend,
      'majoration_saison': majorationSaison,
      'remise_longue_duree': remiseLongueDuree,
      'superficie': superficie,
      'proprietaire_id': proprietaireId,
      'capacite': capacite,
      'nb_chambres': nbChambres,
      'equipements': listeEnJson(equipements.map((e) => e.valeur)),
      'photos': listeEnJson(photos),
      'telephone': texte(telephone),
      'heure_arrivee': heureArrivee,
      'heure_depart': heureDepart,
      'statut': statut.valeur,
      'cree_le': (creeLe ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }
}
