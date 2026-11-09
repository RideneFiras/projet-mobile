import 'package:flutter/material.dart';

import 'vehicule.dart';

/// Option payante ajoutée à une location, facturée par jour.
/// Stockée dans location_vehicule.options en JSON : ["gps","assurance_tous_risques"].
enum OptionLocation {
  siegeBebe('siege_bebe', 'Siège bébé', 5, Icons.child_friendly, [TypeVehicule.voiture]),
  gps('gps', 'GPS', 4, Icons.navigation_outlined, [TypeVehicule.voiture]),
  casque('casque', 'Casque supplémentaire', 3, Icons.sports_motorsports_outlined,
      [TypeVehicule.moto]),
  antivol('antivol', 'Antivol', 1, Icons.lock_outline, [TypeVehicule.bicyclette]),
  assurance('assurance_tous_risques', 'Assurance tous risques', 10, Icons.verified_user_outlined,
      TypeVehicule.values);

  const OptionLocation(this.valeur, this.libelle, this.prixParJour, this.icone, this.types);

  final String valeur;
  final String libelle;

  /// Prix en DT par jour de location.
  final double prixParJour;
  final IconData icone;

  /// Types de véhicule pour lesquels l'option est proposée.
  final List<TypeVehicule> types;

  bool autorisePour(TypeVehicule type) => types.contains(type);

  /// Options proposées pour un type de véhicule (ordre de l'énumération).
  static List<OptionLocation> pour(TypeVehicule type) =>
      [for (final o in OptionLocation.values) if (o.autorisePour(type)) o];

  static OptionLocation? depuis(String valeur) {
    for (final o in OptionLocation.values) {
      if (o.valeur == valeur) return o;
    }
    return null;
  }

  /// Somme des prix journaliers d'une liste d'options.
  static double totalParJour(Iterable<OptionLocation> options) =>
      options.fold(0.0, (somme, o) => somme + o.prixParJour);
}
