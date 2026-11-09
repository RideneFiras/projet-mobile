import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/travel_button.dart';

/// Introduction en 3 écrans (UI Kit, pages 8 à 10) : illustration en arche,
/// titre, texte, points de pagination, bouton « Suivant » puis « Commencer ».
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controle = PageController();
  int _page = 0;

  static const List<_Diapositive> _diapositives = [
    _Diapositive(
      image: 'assets/images/onboarding_1.jpg',
      titre: 'Planifiez votre voyage',
      texte:
          'Créez un voyage, suivez votre budget et regroupez toutes vos réservations au même endroit.',
    ),
    _Diapositive(
      image: 'assets/images/onboarding_2.jpg',
      titre: 'Tout réserver au même endroit',
      texte:
          'Transport, location de voiture et hébergement sont rattachés à votre voyage.',
    ),
    _Diapositive(
      image: 'assets/images/onboarding_3.jpg',
      titre: 'Voyagez avec la communauté',
      texte:
          'Lisez les actualités, échangez sur le forum et partagez vos avis avant de réserver.',
    ),
  ];

  bool get _derniere => _page == _diapositives.length - 1;

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  void _allerConnexion() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _suivant() {
    if (_derniere) {
      Navigator.pushNamed(context, AppRoutes.signup);
      return;
    }
    _controle.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: _allerConnexion,
                  child: const Text(
                    'Passer',
                    style: TextStyle(
                      color: AppColors.orangeText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controle,
                itemCount: _diapositives.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _Vue(diapositive: _diapositives[i]),
              ),
            ),
            _Points(actif: _page, total: _diapositives.length),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TravelButton(
                texte: _derniere ? 'Commencer' : 'Suivant',
                onPressed: _suivant,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 24,
              child: _derniere
                  ? TravelLinkRow(
                      question: "J'ai déjà un compte ·",
                      lien: 'Se connecter',
                      onTap: _allerConnexion,
                    )
                  : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Texte et illustration d'un écran d'introduction.
class _Vue extends StatelessWidget {
  final _Diapositive diapositive;

  const _Vue({required this.diapositive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: AspectRatio(
                aspectRatio: _ratioArche,
                child: ClipPath(
                  clipper: _ArcheClipper(),
                  child: Image.asset(diapositive.image, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          diapositive.titre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            diapositive.texte,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.grey,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Points de pagination : le point actif est une pilule turquoise.
class _Points extends StatelessWidget {
  final int actif;
  final int total;

  const _Points({required this.actif, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == actif ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == actif ? AppColors.teal : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Proportion de l'illustration de la maquette (931 x 1260 px).
const double _ratioArche = 931 / 1260;

/// Découpe en arche : demi-cercle en haut, coins arrondis en bas.
class _ArcheClipper extends CustomClipper<Path> {
  _ArcheClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final rayonCoin = w * 0.06;
    return Path()
      ..moveTo(0, w / 2)
      ..arcTo(Rect.fromLTWH(0, 0, w, w), math.pi, math.pi, false)
      ..lineTo(w, h - rayonCoin)
      ..arcTo(
        Rect.fromCircle(
            center: Offset(w - rayonCoin, h - rayonCoin), radius: rayonCoin),
        0,
        math.pi / 2,
        false,
      )
      ..lineTo(rayonCoin, h)
      ..arcTo(
        Rect.fromCircle(center: Offset(rayonCoin, h - rayonCoin), radius: rayonCoin),
        math.pi / 2,
        math.pi / 2,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Diapositive {
  final String image;
  final String titre;
  final String texte;

  const _Diapositive({
    required this.image,
    required this.titre,
    required this.texte,
  });
}
