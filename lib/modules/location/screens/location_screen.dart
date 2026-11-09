import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import 'locations_tab.dart';
import 'vehicules_tab.dart';

/// Écran d'accueil du module location : deux onglets, Véhicules et Mes locations.
class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
          title: const Text('Location de véhicules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  EnTeteModule(
                    titre: 'Location de véhicules',
                    sousTitre: 'Voiture, moto ou bicyclette : réservez-la pour un de vos voyages.',
                    icone: Icons.directions_car_outlined,
                  ),
                  TabBar(
                    labelColor: AppColors.teal,
                    unselectedLabelColor: AppColors.grey,
                    indicatorColor: AppColors.orange,
                    dividerColor: AppColors.border,
                    tabs: [
                      Tab(text: 'Véhicules'),
                      Tab(text: 'Mes locations'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [VehiculesTab(), LocationsTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
