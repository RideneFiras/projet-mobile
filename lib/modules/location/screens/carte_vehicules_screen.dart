import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/montants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/vehicule.dart';
import 'vehicule_detail_screen.dart';

/// Couleur du marqueur selon le type de véhicule.
Color couleurTypeVehicule(TypeVehicule t) => switch (t) {
      TypeVehicule.voiture => AppColors.teal,
      TypeVehicule.moto => AppColors.orange,
      TypeVehicule.bicyclette => const Color(0xFF2E8B57),
    };

/// Carte des véhicules : un marqueur coloré par type, regroupés quand on dézoome
/// (le chiffre indique le nombre de véhicules ; un appui zoome sur le groupe).
class CarteVehiculesScreen extends StatefulWidget {
  final List<Vehicule> vehicules;
  final bool gestion;

  const CarteVehiculesScreen({super.key, required this.vehicules, this.gestion = false});

  @override
  State<CarteVehiculesScreen> createState() => _CarteVehiculesScreenState();
}

class _CarteVehiculesScreenState extends State<CarteVehiculesScreen> {
  static const LatLng _tunisie = LatLng(35.8, 10.0);
  final _controleur = MapController();
  double _zoom = 6.5;
  Vehicule? _selection;

  List<Vehicule> get _places => widget.vehicules.where((v) => v.aPosition).toList();

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _zoomChange(MapCamera camera, bool _) {
    final z = (camera.zoom * 2).round() / 2; // regroupement recalculé par demi-niveau
    if (z == _zoom) return;
    _zoom = z;
    // Hors de la phase de construction de la carte.
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _ouvrir(Vehicule v) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VehiculeDetailScreen(vehiculeId: v.id!, gestion: widget.gestion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;
    final groupes = regrouperPoints<Vehicule>(
      places,
      latitude: (v) => v.latitude!,
      longitude: (v) => v.longitude!,
      zoom: _zoom,
    );
    final sansPosition = widget.vehicules.length - places.length;

    return EcranModule(
      titre: 'Carte des véhicules',
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
                      width: g.estSeul ? 44 : 52,
                      height: g.estSeul ? 44 : 52,
                      child: g.estSeul ? _marqueur(g.elements.first) : _groupe(g),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final t in TypeVehicule.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icone, size: 16, color: couleurTypeVehicule(t)),
                        const SizedBox(width: 6),
                        Text(t.libelle, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (sansPosition > 0)
                    Text('$sansPosition sans position',
                        style: const TextStyle(fontSize: 11, color: AppColors.grey)),
                ],
              ),
            ),
          ),
          if (_selection != null)
            Positioned(left: 12, right: 12, bottom: 16, child: _apercu(_selection!)),
        ],
      ),
    );
  }

  Widget _marqueur(Vehicule v) => GestureDetector(
        onTap: () => setState(() => _selection = v),
        child: Container(
          decoration: BoxDecoration(
            color: couleurTypeVehicule(v.type),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Color(0x33000000))],
          ),
          child: Icon(v.type.icone, color: AppColors.white, size: 20),
        ),
      );

  Widget _groupe(GroupeCarte<Vehicule> g) => GestureDetector(
        onTap: () => _controleur.move(LatLng(g.latitude, g.longitude), _zoom + 2),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.navy,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 3),
          ),
          alignment: Alignment.center,
          child: Text('${g.elements.length}',
              style: const TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      );

  Widget _apercu(Vehicule v) => CarteModule(
        onTap: () => _ouvrir(v),
        child: Row(
          children: [
            Icon(v.type.icone, color: couleurTypeVehicule(v.type), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.nom,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(v.adresse ?? v.resumeTechnique,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            ),
            Text('${Montants.affiche(v.prixParJour)}/j',
                style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800)),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
}
