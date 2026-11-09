import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import 'avis_tab.dart';
import 'sujets_tab.dart';

/// Écran du forum : discussions entre utilisateurs et avis sur les services.
class ForumScreen extends StatelessWidget {
  /// 0 = Discussions, 1 = Avis.
  final int ongletInitial;

  const ForumScreen({super.key, this.ongletInitial = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: ongletInitial,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
          title: const Text('Forum',
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
                    titre: 'Forum',
                    sousTitre: 'Échangez entre voyageurs et notez les services utilisés.',
                    icone: Icons.forum_outlined,
                  ),
                  const TabBar(
                    labelColor: AppColors.teal,
                    unselectedLabelColor: AppColors.grey,
                    indicatorColor: AppColors.orange,
                    dividerColor: AppColors.border,
                    tabs: [
                      Tab(text: 'Discussions'),
                      Tab(text: 'Avis'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [SujetsTab(), AvisTab()],
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
