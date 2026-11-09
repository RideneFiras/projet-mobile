import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../role.dart';
import '../user_repository.dart';
import '../utilisateur.dart';

/// Affiche [enfant] seulement si l'utilisateur connecté est administrateur.
/// Le rôle est relu en base à chaque ouverture (jamais depuis les préférences).
class GardeAdmin extends StatelessWidget {
  final String titre;
  final Widget enfant;

  const GardeAdmin({super.key, required this.titre, required this.enfant});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Utilisateur?>(
      future: UserRepository().utilisateurConnecte(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data?.role != Role.admin) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              title: Text(titre),
            ),
            body: const EtatVideModule(
              icone: Icons.lock_outline,
              titre: 'Accès réservé',
              message: 'Cette section est réservée à l\'administrateur.',
            ),
          );
        }
        return enfant;
      },
    );
  }
}
