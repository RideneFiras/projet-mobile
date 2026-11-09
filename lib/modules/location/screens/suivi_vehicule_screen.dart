import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/vehicule.dart';
import '../suivi_simulateur.dart';

/// Suivi d'un véhicule en location (SIMULÉ : aucune localisation réelle) avec
/// géorepérage : alerte dès que le véhicule sort de la zone autorisée.
class SuiviVehiculeScreen extends StatefulWidget {
  final Vehicule vehicule;
  final String? client;

  const SuiviVehiculeScreen({super.key, required this.vehicule, this.client});

  @override
  State<SuiviVehiculeScreen> createState() => _SuiviVehiculeScreenState();
}

class _SuiviVehiculeScreenState extends State<SuiviVehiculeScreen> {
  /// Point de départ si le véhicule n'a pas de position : Tunis.
  static const LatLng _tunis = LatLng(36.8065, 10.1815);
  static const _intervalle = Duration(seconds: 3);

  final _controleur = MapController();
  late SimulateurSuivi _simulateur;
  late PositionSuivi _position;
  final List<LatLng> _trace = [];
  Timer? _minuteur;
  double _rayonKm = 5;
  bool _alerteDonnee = false;

  LatLng get _centre => widget.vehicule.aPosition
      ? LatLng(widget.vehicule.latitude!, widget.vehicule.longitude!)
      : _tunis;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  void _demarrer() {
    _minuteur?.cancel();
    _simulateur = SimulateurSuivi(
      latitudeCentre: _centre.latitude,
      longitudeCentre: _centre.longitude,
      rayonKm: _rayonKm,
    );
    _position = _simulateur.position;
    _trace
      ..clear()
      ..add(_centre);
    _alerteDonnee = false;
    _minuteur = Timer.periodic(_intervalle, (_) => _etape());
  }

  void _etape() {
    if (!mounted) return;
    final p = _simulateur.avancer();
    setState(() {
      _position = p;
      _trace.add(LatLng(p.latitude, p.longitude));
    });
    if (p.horsZone && !_alerteDonnee) {
      _alerteDonnee = true;
      afficherMessage(context,
          '${widget.vehicule.nom} est sorti de la zone autorisée (${_rayonKm.round()} km)',
          erreur: true);
    } else if (!p.horsZone) {
      _alerteDonnee = false;
    }
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _position;
    final ici = LatLng(p.latitude, p.longitude);
    return EcranModule(
      titre: 'Suivi · ${widget.vehicule.nom}',
      corps: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: p.horsZone ? const Color(0xFFFBE3E0) : AppColors.tealLight,
            child: Row(
              children: [
                Icon(p.horsZone ? Icons.warning_amber_rounded : Icons.gps_fixed,
                    color: p.horsZone ? AppColors.danger : AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.horsZone
                        ? 'HORS ZONE · à ${distanceLisible(p.distanceKm)} du point de départ'
                        : 'Dans la zone · à ${distanceLisible(p.distanceKm)} du point de départ',
                    style: TextStyle(
                        color: p.horsZone ? AppColors.danger : AppColors.teal,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _controleur,
              options: MapOptions(initialCenter: _centre, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.projet_mobile',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _centre,
                      radius: _rayonKm * 1000,
                      useRadiusInMeter: true,
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderColor: AppColors.teal,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(points: List.of(_trace), color: AppColors.orange, strokeWidth: 3),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: ici,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.horsZone ? AppColors.danger : AppColors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 3),
                        ),
                        child: Icon(widget.vehicule.type.icone,
                            color: AppColors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.client != null)
                  Text('Client : ${widget.client}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                Text('Zone autorisée : ${_rayonKm.round()} km autour du point de départ',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: _rayonKm,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${_rayonKm.round()} km',
                  activeColor: AppColors.teal,
                  onChanged: (v) => setState(() => _rayonKm = v),
                  onChangeEnd: (_) => _demarrer(),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Simulation : nouvelle position toutes les 3 s.',
                          style: TextStyle(color: AppColors.grey, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () => _controleur.move(ici, 13),
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Centrer'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(_demarrer),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Recommencer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
