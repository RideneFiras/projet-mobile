import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bouton principal du UI Kit : pilule turquoise de 54 px, texte blanc gras.
/// Pendant le chargement il garde sa couleur et affiche un petit cercle blanc.
class TravelButton extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed;
  final bool chargement;

  const TravelButton({
    super.key,
    required this.texte,
    required this.onPressed,
    this.chargement = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.teal,
          disabledForegroundColor: AppColors.white,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: chargement ? null : onPressed,
        child: chargement
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.white),
              )
            : Text(texte),
      ),
    );
  }
}

/// Ligne « Pas encore de compte ? Créer un compte » (lien orange gras).
class TravelLinkRow extends StatelessWidget {
  final String question;
  final String lien;
  final VoidCallback onTap;

  const TravelLinkRow(
      {super.key, required this.question, required this.lien, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$question ',
            style: const TextStyle(color: AppColors.grey, fontSize: 15)),
        GestureDetector(
          onTap: onTap,
          child: Text(lien,
              style: const TextStyle(
                  color: AppColors.orangeText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
