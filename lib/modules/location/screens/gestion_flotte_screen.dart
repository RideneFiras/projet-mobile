import 'package:flutter/material.dart';

import '../../../core/widgets/ui_kit.dart';
import 'vehicules_tab.dart';

/// Espace administrateur : gestion complète de la flotte (ajout, modification, suppression).
/// Le voyageur n'y accède pas : il réserve les véhicules depuis « Location de voiture ».
class GestionFlotteScreen extends StatelessWidget {
  const GestionFlotteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: 'Gérer la flotte',
      corps: const Column(
        children: [
          EnTeteModule(
            titre: 'Flotte',
            sousTitre: 'Véhicules proposés aux voyageurs. Un véhicule indisponible n\'est pas réservable.',
            icone: Icons.directions_car_outlined,
          ),
          Expanded(child: VehiculesTab(gestion: true)),
        ],
      ),
    );
  }
}
