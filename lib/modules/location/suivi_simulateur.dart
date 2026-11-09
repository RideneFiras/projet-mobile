import 'dart:math' as math;

import '../../core/utils/geo.dart';

/// Position simulée d'un véhicule en location.
typedef PositionSuivi = ({double latitude, double longitude, double distanceKm, bool horsZone});

/// Suivi GPS SIMULÉ (pas de localisation réelle) avec géorepérage :
/// à chaque appel de [avancer], le véhicule se déplace de quelques centaines de mètres
/// dans une direction qui évolue doucement ; [horsZone] passe à true dès qu'il s'éloigne
/// de plus de [rayonKm] du point de départ.
class SimulateurSuivi {
  final double latitudeCentre;
  final double longitudeCentre;
  final double rayonKm;

  /// Distance parcourue à chaque étape (km).
  final double pasKm;
  final math.Random _alea;

  double _latitude;
  double _longitude;
  double _cap;

  SimulateurSuivi({
    required this.latitudeCentre,
    required this.longitudeCentre,
    this.rayonKm = 20,
    this.pasKm = 0.8,
    math.Random? alea,
  })  : _alea = alea ?? math.Random(),
        _latitude = latitudeCentre,
        _longitude = longitudeCentre,
        _cap = 0 {
    _cap = _alea.nextDouble() * 2 * math.pi;
  }

  PositionSuivi get position => _etat();

  /// Nouvelle position après une étape de déplacement.
  PositionSuivi avancer() {
    _cap += (_alea.nextDouble() - 0.5) * 0.8; // virage léger
    final pas = pasKm * (0.5 + _alea.nextDouble());
    const kmParDegreLatitude = 111.32;
    final kmParDegreLongitude = kmParDegreLatitude * math.cos(_latitude * math.pi / 180);
    _latitude += pas * math.cos(_cap) / kmParDegreLatitude;
    _longitude += pas * math.sin(_cap) / kmParDegreLongitude;
    return _etat();
  }

  PositionSuivi _etat() {
    final d = distanceKm(latitudeCentre, longitudeCentre, _latitude, _longitude);
    return (latitude: _latitude, longitude: _longitude, distanceKm: d, horsZone: d > rayonKm);
  }
}
