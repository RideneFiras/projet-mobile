import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Une photo : URL (http/https) ou asset du projet (assets/…).
/// Toute autre valeur, ou une image introuvable, affiche [iconeParDefaut].
class PhotoModule extends StatelessWidget {
  final String? source;
  final IconData iconeParDefaut;
  final double? hauteur;
  final double? largeur;
  final double rayon;

  const PhotoModule({
    super.key,
    required this.source,
    required this.iconeParDefaut,
    this.hauteur,
    this.largeur,
    this.rayon = 14,
  });

  @override
  Widget build(BuildContext context) {
    final s = source?.trim() ?? '';
    Widget repli(BuildContext _, Object __, StackTrace? ___) => _vide();
    final Widget image;
    if (s.startsWith('http://') || s.startsWith('https://')) {
      image = Image.network(s,
          fit: BoxFit.cover, width: largeur, height: hauteur, errorBuilder: repli);
    } else if (s.startsWith('assets/')) {
      image = Image.asset(s,
          fit: BoxFit.cover, width: largeur, height: hauteur, errorBuilder: repli);
    } else {
      image = _vide();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(rayon), child: image);
  }

  Widget _vide() => Container(
        width: largeur,
        height: hauteur,
        color: AppColors.tealLight,
        alignment: Alignment.center,
        child: Icon(iconeParDefaut, color: AppColors.teal, size: 40),
      );
}

/// Galerie défilante en haut d'un écran de détail, avec indicateur « 1 / 4 ».
class GaleriePhotos extends StatefulWidget {
  final List<String> photos;
  final IconData iconeParDefaut;
  final double hauteur;

  const GaleriePhotos({
    super.key,
    required this.photos,
    required this.iconeParDefaut,
    this.hauteur = 220,
  });

  @override
  State<GaleriePhotos> createState() => _GaleriePhotosState();
}

class _GaleriePhotosState extends State<GaleriePhotos> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return PhotoModule(
        source: null,
        iconeParDefaut: widget.iconeParDefaut,
        hauteur: widget.hauteur,
        largeur: double.infinity,
        rayon: 18,
      );
    }
    return SizedBox(
      height: widget.hauteur,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.photos.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (_, i) => PhotoModule(
              source: widget.photos[i],
              iconeParDefaut: widget.iconeParDefaut,
              hauteur: widget.hauteur,
              largeur: double.infinity,
              rayon: 18,
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_page + 1} / ${widget.photos.length}',
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
