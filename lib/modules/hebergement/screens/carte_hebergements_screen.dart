import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/hebergement.dart';
import 'hebergement_detail_screen.dart';

/// Carte des établissements : le prix par nuit s'affiche sur chaque marqueur ;
/// au dézoom, les marqueurs proches sont regroupés (nombre + prix minimum).
class CarteHebergementsScreen extends StatefulWidget {
  final List<Hebergement> hebergements;
  final bool gestion;

  const CarteHebergementsScreen({super.key, required this.hebergements, this.gestion = false});

  @override
  State<CarteHebergementsScreen> createState() => _CarteHebergementsScreenState();
}

class _CarteHebergementsScreenState extends State<CarteHebergementsScreen> {
  static const LatLng _tunisie = LatLng(35.8, 10.0);
  final _controleur = MapController();
  double _zoom = 6.5;
  Hebergement? _selection;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _zoomChange(MapCamera camera, bool _) {
    final z = (camera.zoom * 2).round() / 2;
    if (z == _zoom) return;
    _zoom = z;
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.hebergements.where((h) => h.aPosition).toList();
    final groupes = regrouperPoints<Hebergement>(
      places,
      latitude: (h) => h.latitude!,
      longitude: (h) => h.longitude!,
      zoom: _zoom,
      taillePixels: 80,
    );
    return EcranModule(
      titre: 'Carte des hébergements',
      corps: Stack(
        children: [
          FlutterMap(
            mapController: _controleur,
            options: MapOptions(
              initialCenter: places.isEmpty
                  ? _tunisie
                  : LatLng(places.first.latitude!, places.first.longitude!),
              initialZoom: _zoom,
              onPositionChanged: _zoomChange,
              onTap: (_, __) => setState(() => _selection = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.projet_mobile',
              ),
              MarkerLayer(
                markers: [
                  for (final g in groupes)
                    Marker(
                      point: LatLng(g.latitude, g.longitude),
                      width: 96,
                      height: 36,
                      child: g.estSeul ? _prix(g.elements.first) : _groupe(g),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          if (places.length < widget.hebergements.length)
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.white, borderRadius: BorderRadius.circular(12)),
                child: Text(
                    '${widget.hebergements.length - places.length} établissement(s) sans position',
                    style: const TextStyle(fontSize: 12, color: AppColors.grey)),
              ),
            ),
          if (_selection != null)
            Positioned(left: 12, right: 12, bottom: 16, child: _apercu(_selection!)),
        ],
      ),
    );
  }

  Widget _prix(Hebergement h) {
    final actif = _selection?.id == h.id;
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _selection = h),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: actif ? AppColors.navy : AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: actif ? AppColors.navy : AppColors.teal, width: 2),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Color(0x33000000))],
          ),
          child: Text('${h.prixParNuit.toStringAsFixed(0)} DT',
              style: TextStyle(
                  color: actif ? AppColors.white : AppColors.teal,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _groupe(GroupeCarte<Hebergement> g) {
    final min = g.elements.map((h) => h.prixParNuit).reduce((a, b) => a < b ? a : b);
    return Center(
      child: GestureDetector(
        onTap: () => _controleur.move(LatLng(g.latitude, g.longitude), _zoom + 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: AppColors.teal, borderRadius: BorderRadius.circular(18)),
          child: Text('${g.elements.length} · dès ${min.toStringAsFixed(0)} DT',
              style: const TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _apercu(Hebergement h) => CarteModule(
        onTap: () => Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HebergementDetailScreen(hebergementId: h.id!, gestion: widget.gestion),
          ),
        ),
        child: Row(
          children: [
            Icon(h.type.icone, color: AppColors.teal, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(
                      '${h.type.libelle}${h.nbAvis > 0 ? ' · ★ ${h.noteMoyenne.toStringAsFixed(1)}' : ''}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            ),
            Text('${Montants.affiche(h.prixParNuit)}/nuit',
                style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800)),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
}
