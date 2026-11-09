import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Thème global du UI Kit : police Plus Jakarta Sans, barre d'en-tête sans
/// ombre, barre de navigation du bas (pastille turquoise sur l'onglet actif).
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.teal,
        secondary: AppColors.orange,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.navy,
        displayColor: AppColors.navy,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        titleTextStyle: TextStyle(
          color: AppColors.navy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.tealLight,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (etats) => IconThemeData(
            size: 24,
            color: etats.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.grey,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (etats) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: etats.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.grey,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
