import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Signature manuscrite simple : chaque trait est une liste de points (coordonnées locales).
/// [onChange] reçoit les traits et la taille de la zone (pour les reporter dans un PDF).
class ZoneSignature extends StatefulWidget {
  final void Function(List<List<Offset>> traits, Size taille) onChange;
  final double hauteur;

  const ZoneSignature({super.key, required this.onChange, this.hauteur = 160});

  @override
  State<ZoneSignature> createState() => _ZoneSignatureState();
}

class _ZoneSignatureState extends State<ZoneSignature> {
  final List<List<Offset>> _traits = [];
  Size _taille = Size.zero;

  void _notifier() => widget.onChange(
      [for (final t in _traits) List<Offset>.unmodifiable(t)], _taille);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, contraintes) {
            _taille = Size(contraintes.maxWidth, widget.hauteur);
            return Container(
              height: widget.hauteur,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  onPanStart: (d) => setState(() => _traits.add([d.localPosition])),
                  onPanUpdate: (d) {
                    final p = d.localPosition;
                    if (p.dx < 0 || p.dy < 0 || p.dx > _taille.width || p.dy > _taille.height) {
                      return;
                    }
                    setState(() => _traits.last.add(p));
                  },
                  onPanEnd: (_) => _notifier(),
                  child: CustomPaint(
                    painter: _PeintreSignature(_traits),
                    child: _traits.isEmpty
                        ? const Center(
                            child: Text('Signez ici avec le doigt',
                                style: TextStyle(color: AppColors.grey)),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _traits.isEmpty
                ? null
                : () {
                    setState(_traits.clear);
                    _notifier();
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Effacer'),
          ),
        ),
      ],
    );
  }
}

class _PeintreSignature extends CustomPainter {
  final List<List<Offset>> traits;

  _PeintreSignature(this.traits);

  @override
  void paint(Canvas canvas, Size size) {
    final pinceau = Paint()
      ..color = AppColors.navy
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final t in traits) {
      if (t.length == 1) {
        canvas.drawCircle(t.first, 1.2, pinceau);
        continue;
      }
      final chemin = Path()..moveTo(t.first.dx, t.first.dy);
      for (final p in t.skip(1)) {
        chemin.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(chemin, pinceau);
    }
  }

  @override
  bool shouldRepaint(_PeintreSignature ancien) => true;
}
