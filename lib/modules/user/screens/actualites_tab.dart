import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../actualite.dart';
import '../user_repository.dart';
import 'widgets_accueil.dart';

/// Onglet « Actualités » : toutes les annonces publiées par l'administrateur,
/// sous un titre simple dans le style de la page « Mon profil ».
class ActualitesTab extends StatefulWidget {
  const ActualitesTab({super.key});

  @override
  State<ActualitesTab> createState() => _ActualitesTabState();
}

class _ActualitesTabState extends State<ActualitesTab> {
  late Future<List<Actualite>> _future = UserRepository().actualites();

  Future<void> _recharger() async {
    // Bloc et non fléchée : setState ne doit pas renvoyer de Future.
    setState(() {
      _future = UserRepository().actualites();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _recharger,
      child: FutureBuilder<List<Actualite>>(
        future: _future,
        builder: (context, snap) {
          final items = snap.data ?? const <Actualite>[];
          final Widget contenu = !snap.hasData
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : items.isEmpty
                  ? const EtatVideModule(
                      icone: Icons.newspaper_outlined,
                      titre: 'Aucune actualité',
                      message: "L'administrateur publiera ici les prochaines annonces.",
                    )
                  : Column(
                      children: [
                        for (final a in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CarteActualite(actualite: a, complete: true),
                          ),
                      ],
                    );
          return ListView(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.paddingOf(context).top + 16, 20, 24),
            children: [
              const Text(
                'Actualités',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Les annonces publiées par la plateforme.',
                style: TextStyle(fontSize: 14, color: AppColors.grey),
              ),
              const SizedBox(height: 20),
              contenu,
            ],
          );
        },
      ),
    );
  }
}
