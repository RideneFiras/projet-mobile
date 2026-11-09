import 'package:flutter/material.dart';

/// Palette du UI Kit Travel Platform. Utilisez TOUJOURS ces constantes,
/// jamais de Color(0xFF...) écrit en dur dans un écran.
class AppColors {
  AppColors._();

  static const Color teal = Color(0xFF0F7B83); // boutons, en-têtes
  static const Color tealDark = Color(0xFF0A5C63); // vague du bas
  static const Color tealMid = Color(0xFF2B969C); // vague du milieu
  static const Color tealLight = Color(0xFFE2F1F1); // fonds d'icônes, chips
  static const Color orange = Color(0xFFF68B3F); // soleil, cartes mises en avant
  static const Color orangeText = Color(0xFFC2581E); // liens « Créer un compte »
  static const Color orangeLight = Color(0xFFFDEBDC);
  static const Color navy = Color(0xFF13263B); // titres, en-tête admin
  static const Color grey = Color(0xFF5B6B7B); // texte secondaire
  static const Color border = Color(0xFFE2E8EE);
  static const Color background = Color(0xFFF5F7F9);
  static const Color disabled = Color(0xFFEDF1F4);
  static const Color danger = Color(0xFFC0392B);
  static const Color white = Colors.white;
}
