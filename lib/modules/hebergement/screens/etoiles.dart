import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Étoiles de classement d'un hôtel (1 à 5).
class Etoiles extends StatelessWidget {
  final int nombre;
  final double taille;

  const Etoiles({super.key, required this.nombre, this.taille = 16});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < nombre; i++)
            Icon(Icons.star_rounded, size: taille, color: AppColors.orange),
        ],
      );
}
