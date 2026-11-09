import 'dart:math' as math;

/// Outils géographiques sans package : distance, regroupement de marqueurs.

/// Distance à vol d'oiseau en kilomètres (formule de haversine).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const rayonTerre = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return rayonTerre * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// « 850 m » / « 12,4 km ».
String distanceLisible(double km) => km < 1
    ? '${(km * 1000).round()} m'
    : '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';

/// Groupe de points proches à un niveau de zoom donné.
class GroupeCarte<T> {
  final List<T> elements;
  final double latitude;
  final double longitude;

  const GroupeCarte(this.elements, this.latitude, this.longitude);

  bool get estSeul => elements.length == 1;
}

/// Regroupe les points dans une grille dont chaque case mesure environ [taillePixels]
/// à l'écran au [zoom] donné (projection Web Mercator : 256 px par tuile).
/// Chaque groupe est placé au barycentre de ses points.
List<GroupeCarte<T>> regrouperPoints<T>(
  List<T> elements, {
  required double Function(T) latitude,
  required double Function(T) longitude,
  required double zoom,
  double taillePixels = 60,
}) {
  final degresParPixel = 360 / (256 * math.pow(2, zoom));
  final cellule = taillePixels * degresParPixel;
  final cases = <(int, int), List<T>>{};
  for (final e in elements) {
    final cle = ((latitude(e) / cellule).floor(), (longitude(e) / cellule).floor());
    (cases[cle] ??= []).add(e);
  }
  return [
    for (final groupe in cases.values)
      GroupeCarte<T>(
        groupe,
        groupe.map(latitude).reduce((a, b) => a + b) / groupe.length,
        groupe.map(longitude).reduce((a, b) => a + b) / groupe.length,
      ),
  ];
}
