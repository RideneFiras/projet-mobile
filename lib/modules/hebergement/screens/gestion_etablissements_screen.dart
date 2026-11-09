import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import 'hebergements_tab.dart';
import 'sejours_admin_tab.dart';

/// Espace administrateur de l'hébergement, en deux onglets :
/// - Établissements : catalogue (ajout, modification, fermetures, statut) ;
/// - Séjours : réception (check-in par code, check-out) et historique.
/// Le voyageur n'y accède pas : il réserve depuis « Hébergement ».
class GestionEtablissementsScreen extends StatelessWidget {
  const GestionEtablissementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: EcranModule(
        titre: 'Gérer les établissements',
        corps: const Column(
          children: [
            EnTeteModule(
              titre: 'Hébergement',
              sousTitre: 'Catalogue des établissements et accueil des voyageurs.',
              icone: Icons.bed_outlined,
            ),
            TabBar(
              labelColor: AppColors.teal,
              unselectedLabelColor: AppColors.grey,
              indicatorColor: AppColors.orange,
              dividerColor: AppColors.border,
              tabs: [
                Tab(text: 'Établissements'),
                Tab(text: 'Séjours'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  HebergementsTab(gestion: true),
                  SejoursAdminTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
