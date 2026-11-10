/// Capture d'un visage par la caméra.
/// Web : web/face_auth.js (face-api.js). Autres plateformes : non disponible.
library;

export 'capture_visage_stub.dart'
    if (dart.library.js_interop) 'capture_visage_web.dart';

/// Résultat d'une capture : descripteur, erreur, ou annulation.
class CaptureVisage {
  final List<double>? descripteur;
  final String? erreur;

  const CaptureVisage({this.descripteur, this.erreur});

  bool get annulee => descripteur == null && erreur == null;
}
