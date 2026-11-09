import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/travel_header.dart';
import '../user_repository.dart';

/// Écran de démarrage (UI Kit, page 1) : marque sur fond turquoise et trois points.
/// Ouvre l'accueil si une session existe, sinon l'introduction.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    final enCours = UserRepository().utilisateurConnecte();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final utilisateur = await enCours;
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      utilisateur == null ? AppRoutes.onboarding : AppRoutes.home,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(
            painter: TravelWavePainter(
              soleil: Offset(0.82, 0.14),
              rayonSoleil: 0.14,
              nuagesY: 0.18,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),
                const TravelLogo(taille: 120),
                const SizedBox(height: 26),
                const Text(
                  'Travel Platform',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Voyagez simplement',
                  style: TextStyle(color: AppColors.white, fontSize: 17),
                ),
                const Spacer(flex: 6),
                const _Points(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Les trois points de la maquette (le premier est actif, en blanc plein).
class _Points extends StatelessWidget {
  const _Points();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i == 0 ? AppColors.white : const Color(0x66FFFFFF),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
