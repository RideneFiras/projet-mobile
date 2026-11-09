import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import 'reservations_admin_tab.dart';
import 'vehicules_tab.dart';

/// Espace administrateur du module location, en deux onglets :
/// - Flotte : ajout, modification, statut et suppression des véhicules ;
/// - Réservations : statistiques et suivi de toutes les locations (annuler, clôturer).
/// Le voyageur n'y accède pas : il réserve depuis « Location de véhicules ».
class GestionFlotteScreen extends StatelessWidget {
  const GestionFlotteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: EcranModule(
        titre: 'Gérer la flotte',
        corps: const Column(
          children: [
            EnTeteModule(
              titre: 'Location de véhicules',
              sousTitre: 'Flotte proposée aux voyageurs et suivi des réservations.',
              icone: Icons.directions_car_outlined,
            ),
            TabBar(
              labelColor: AppColors.teal,
              unselectedLabelColor: AppColors.grey,
              indicatorColor: AppColors.orange,
              dividerColor: AppColors.border,
              tabs: [
                Tab(text: 'Flotte'),
                Tab(text: 'Réservations'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  VehiculesTab(gestion: true),
                  ReservationsAdminTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
