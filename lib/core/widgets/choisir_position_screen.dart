import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocodage_service.dart';
import '../theme/app_colors.dart';
import 'ui_kit.dart';

/// Position choisie sur la carte ; [adresse] est null si le géocodage inverse a échoué
/// (hors connexion) : les coordonnées restent valables.
typedef PositionChoisie = ({double latitude, double longitude, String? adresse});

/// Choix d'une position : l'utilisateur touche la carte, un marqueur se place,
/// « Valider » renvoie la position et son adresse (Nominatim).
class ChoisirPositionScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const ChoisirPositionScreen({super.key, this.latitude, this.longitude});

  @override
  State<ChoisirPositionScreen> createState() => _ChoisirPositionScreenState();
}

class _ChoisirPositionScreenState extends State<ChoisirPositionScreen> {
  /// Centre par défaut : Tunis.
  static const LatLng _tunis = LatLng(36.8065, 10.1815);

  final _geocodage = GeocodageService();
  LatLng? _point;
  bool _validation = false;

  @override
  void initState() {
    super.initState();
    if (widget.latitude != null && widget.longitude != null) {
      _point = LatLng(widget.latitude!, widget.longitude!);
    }
  }

  Future<void> _valider() async {
    final p = _point;
    if (p == null) return;
    setState(() => _validation = true);
    final adresse = await _geocodage.adresseDepuisPosition(p.latitude, p.longitude);
    if (!mounted) return;
    if (adresse == null && _geocodage.derniereErreur != null) {
      afficherMessage(context, '${_geocodage.derniereErreur} — position conservée',
          erreur: true);
    }
    Navigator.pop<PositionChoisie>(
      context,
      (latitude: p.latitude, longitude: p.longitude, adresse: adresse),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _point;
    return EcranModule(
      titre: 'Choisir la position',
      corps: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: p ?? _tunis,
                initialZoom: p == null ? 11 : 15,
                onTap: (_, point) => setState(() => _point = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.projet_mobile',
                ),
                if (p != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: p,
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on,
                            color: AppColors.orange, size: 48),
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
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            color: AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p == null
                      ? 'Touchez la carte pour placer le point.'
                      : 'Position : ${p.latitude.toStringAsFixed(5)}, '
                          '${p.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                BoutonPrincipal(
                  libelle: _validation ? 'Recherche de l\'adresse…' : 'Valider',
                  icone: Icons.check,
                  onPressed: (p == null || _validation) ? null : _valider,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
