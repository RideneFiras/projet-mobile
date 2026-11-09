import 'package:flutter/material.dart';

import '../../../core/widgets/ui_kit.dart';
import 'hebergements_tab.dart';

/// Espace administrateur : gestion complète du catalogue des établissements.
/// Le voyageur n'y accède pas : il réserve un séjour depuis « Hébergement ».
class GestionEtablissementsScreen extends StatelessWidget {
  const GestionEtablissementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EcranModule(
      titre: 'Gérer les établissements',
      corps: const Column(
        children: [
          EnTeteModule(
            titre: 'Établissements',
            sousTitre: 'Hôtels et logements proposés. Les séjours existants sont supprimés avec l\'établissement.',
            icone: Icons.bed_outlined,
          ),
          Expanded(child: HebergementsTab(gestion: true)),
        ],
      ),
    );
  }
}
