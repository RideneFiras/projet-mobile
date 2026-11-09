import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo du UI Kit (cercle blanc, boussole turquoise, losange orange),
/// repris tel quel de la maquette.
class TravelLogo extends StatelessWidget {
  final double taille;
  const TravelLogo({super.key, this.taille = 44});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/kit_logo.png',
        width: taille,
        height: taille,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Illustration d'en-tête du UI Kit : ciel turquoise, nuages, soleil orange,
/// trajet en pointillés vers un avion en papier et deux vagues.
class TravelWavePainter extends CustomPainter {
  /// Position du soleil en fraction de la largeur / hauteur.
  final Offset soleil;
  final double rayonSoleil; // fraction de la largeur
  final double nuagesY; // hauteur des nuages, fraction de la hauteur

  const TravelWavePainter({
    this.soleil = const Offset(0.82, 0.32),
    this.rayonSoleil = 0.11,
    this.nuagesY = 0.50,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.teal);

    // Nuages
    final nuage = Paint()..color = const Color(0x2EFFFFFF);
    canvas.drawOval(
        Rect.fromLTWH(w * 0.11, h * nuagesY, w * 0.24, h * 0.09), nuage);
    canvas.drawOval(
        Rect.fromLTWH(w * 0.22, h * (nuagesY - 0.04), w * 0.15, h * 0.08),
        nuage);

    // Soleil
    canvas.drawCircle(Offset(w * soleil.dx, h * soleil.dy), w * rayonSoleil,
        Paint()..color = AppColors.orange);

    // Trajet en pointillés
    final debut = Offset(w * 0.07, h * 0.80);
    final fin = Offset(w * (soleil.dx - 0.08), h * (soleil.dy + 0.06));
    final trajet = Path()
      ..moveTo(debut.dx, debut.dy)
      ..quadraticBezierTo(w * 0.30, h * 0.55, fin.dx, fin.dy);
    final pointille = Paint()
      ..color = AppColors.white
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final ui.PathMetric m in trajet.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 3.5), pointille);
      }
    }

    // Avion en papier
    final a = fin;
    final avion = Path()
      ..moveTo(a.dx - 2, a.dy + 4)
      ..lineTo(a.dx + 22, a.dy - 18)
      ..lineTo(a.dx + 14, a.dy + 10)
      ..close();
    canvas.drawPath(avion, Paint()..color = AppColors.white);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx + 22, a.dy - 18)
        ..lineTo(a.dx + 8, a.dy + 2)
        ..lineTo(a.dx + 14, a.dy + 10)
        ..close(),
      Paint()..color = const Color(0xFFD7ECEC),
    );

    // Vague du milieu
    final vague1 = Path()
      ..moveTo(0, h * 0.86)
      ..cubicTo(w * 0.25, h * 0.72, w * 0.55, h * 0.92, w, h * 0.74)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(vague1, Paint()..color = AppColors.tealMid);

    // Vague du bas
    final vague2 = Path()
      ..moveTo(0, h * 0.95)
      ..cubicTo(w * 0.30, h * 0.84, w * 0.62, h * 1.0, w, h * 0.86)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(vague2, Paint()..color = AppColors.tealDark);
  }

  @override
  bool shouldRepaint(covariant TravelWavePainter oldDelegate) =>
      oldDelegate.soleil != soleil ||
      oldDelegate.rayonSoleil != rayonSoleil ||
      oldDelegate.nuagesY != nuagesY;
}
