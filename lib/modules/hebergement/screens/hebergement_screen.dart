import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import 'hebergements_tab.dart';
import 'sejours_tab.dart';

/// Écran d'accueil du module hébergement : Établissements et Mes séjours.
class HebergementScreen extends StatelessWidget {
  const HebergementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
          title: const Text('Hébergement',
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
                  const EnTeteModule(
                    titre: 'Hébergement',
                    sousTitre: 'Hôtels et logements, réservés pour la durée de votre voyage.',
                    icone: Icons.bed_outlined,
                  ),
                  const TabBar(
                    labelColor: AppColors.teal,
                    unselectedLabelColor: AppColors.grey,
                    indicatorColor: AppColors.orange,
                    dividerColor: AppColors.border,
                    tabs: [
                      Tab(text: 'Établissements'),
                      Tab(text: 'Mes séjours'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [HebergementsTab(), SejoursTab()],
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
