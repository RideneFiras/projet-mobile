import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'transport_trajet_api.dart';

/// Carte du trajet : le tracé routier (ou une ligne droite indicative) entre
/// le point A, au départ, et le point B, à l'arrivée.
/// Dessinée avec un CustomPaint : aucun fond de carte ni paquet supplémentaire.
class CarteTrajet extends StatelessWidget {
  final List<PointGeo> trace;
  final PointGeo? depart;
  final PointGeo? arrivee;
  final bool estime;

  const CarteTrajet({
    super.key,
    required this.trace,
    required this.depart,
    required this.arrivee,
    required this.estime,
  });

  @override
  Widget build(BuildContext context) {
    final d = depart;
    final a = arrivee;
    // Sans tracé (ancien serveur, route absente), on relie simplement A à B.
    final List<PointGeo> points =
        trace.length >= 2 ? trace : [if (d != null) d, if (a != null) a];
    if (points.length < 2) {
      // Pas de coordonnées : le serveur est probablement resté sur l'ancienne version.
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Carte indisponible : relancez le serveur (node index.js) pour afficher le tracé.',
          style: TextStyle(color: AppColors.orangeText, fontSize: 13),
        ),
      );
    }

    final routier = !estime && trace.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: CustomPaint(
            painter: _PeintreTrajet(
              points: points,
              depart: d ?? points.first,
              arrivee: a ?? points.last,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          routier
              ? 'Tracé routier calculé par OpenRouteService'
              : 'Tracé indicatif en ligne droite',
          style: const TextStyle(color: AppColors.grey, fontSize: 12),
        ),
      ],
    );
  }
}

class _PeintreTrajet extends CustomPainter {
  final List<PointGeo> points;
  final PointGeo depart;
  final PointGeo arrivee;

  const _PeintreTrajet({
    required this.points,
    required this.depart,
    required this.arrivee,
  });

  static const double _marge = 30;
  static const Color _vert = Color(0xFF2E8B57);

  @override
  void paint(Canvas canvas, Size taille) {
    _dessinerGrille(canvas, taille);

    final latitudes = points.map((p) => p.lat).toList();
    final longitudes = points.map((p) => p.lon).toList();
    final minLat = latitudes.reduce((x, y) => math.min(x, y));
    final maxLat = latitudes.reduce((x, y) => math.max(x, y));
    final minLon = longitudes.reduce((x, y) => math.min(x, y));
    final maxLon = longitudes.reduce((x, y) => math.max(x, y));

    // Une longitude couvre moins de chemin qu'une latitude : on la corrige par cos(latitude).
    final echelleLon = math.cos(((minLat + maxLat) / 2) * math.pi / 180);
    final largeur = math.max((maxLon - minLon) * echelleLon, 1e-6);
    final hauteur = math.max(maxLat - minLat, 1e-6);
    final zoneL = taille.width - 2 * _marge;
    final zoneH = taille.height - 2 * _marge;
    final zoom = math.min(zoneL / largeur, zoneH / hauteur);
    final origineX = _marge + (zoneL - largeur * zoom) / 2;
    final origineY = _marge + (zoneH - hauteur * zoom) / 2;

    // Nord en haut : la latitude décroît vers le bas de l'écran.
    Offset projeter(PointGeo p) => Offset(
          origineX + (p.lon - minLon) * echelleLon * zoom,
          origineY + (maxLat - p.lat) * zoom,
        );

    final pts = [for (final p in points) projeter(p)];
    final chemin = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      chemin.lineTo(p.dx, p.dy);
    }
    // Liseré blanc sous le tracé, pour le lire sur le quadrillage.
    canvas.drawPath(
      chemin,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      chemin,
      Paint()
        ..color = AppColors.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _etiquette(canvas, projeter(depart), 'A', _vert);
    _etiquette(canvas, projeter(arrivee), 'B', AppColors.danger);
  }

  void _dessinerGrille(Canvas canvas, Size taille) {
    final grille = Paint()
      ..color = const Color(0x1413263B)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = taille.width * i / 4;
      final y = taille.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, taille.height), grille);
      canvas.drawLine(Offset(0, y), Offset(taille.width, y), grille);
    }
  }

  void _etiquette(Canvas canvas, Offset centre, String lettre, Color couleur) {
    canvas.drawCircle(centre, 13, Paint()..color = AppColors.white);
    canvas.drawCircle(centre, 11, Paint()..color = couleur);
    final texte = TextPainter(
      text: TextSpan(
        text: lettre,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texte.paint(canvas, centre - Offset(texte.width / 2, texte.height / 2));
    texte.dispose();
  }

  @override
  bool shouldRepaint(covariant _PeintreTrajet ancien) =>
      ancien.points != points || ancien.depart != depart || ancien.arrivee != arrivee;
}
