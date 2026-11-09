import 'package:flutter/material.dart';

/// Les 4 rôles de la plateforme. "valeur" = ce qui est stocké en base.
enum Role {
  client('client', 'Client', Icons.shopping_bag_outlined,
      'Client : passe des commandes dans une ville et suit leur livraison.'),
  traveller('traveller', 'Voyageur', Icons.work_outline,
      'Voyageur : crée des voyages et réserve ses services.'),
  transporter('transporter', 'Transporteur', Icons.local_shipping_outlined,
      'Transporteur : met en relation commandes et voyageurs du même trajet.'),
  admin('admin', 'Administrateur', Icons.admin_panel_settings_outlined,
      'Administrateur : publie les actualités et gère la plateforme.');

  const Role(this.valeur, this.libelle, this.icone, this.description);

  final String valeur;
  final String libelle;
  final IconData icone;
  final String description;

  /// Rôles proposés à l'inscription (admin exclu).
  static const List<Role> inscription = [client, traveller, transporter];

  static Role depuis(String valeur) =>
      Role.values.firstWhere((r) => r.valeur == valeur, orElse: () => client);
}
