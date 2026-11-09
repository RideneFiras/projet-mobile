import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';

/// Petite carte OpenStreetMap centrée sur un point (véhicule, établissement).
class CarteEmplacement extends StatelessWidget {
  final double latitude;
  final double longitude;
  final IconData icone;
  final double hauteur;

  const CarteEmplacement({
    super.key,
    required this.latitude,
    required this.longitude,
    this.icone = Icons.place,
    this.hauteur = 180,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return SizedBox(
      height: hauteur,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.projet_mobile',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 3),
                    ),
                    child: Icon(icone, color: AppColors.white, size: 20),
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
    );
  }
}
