import 'dart:convert';
import 'dart:js_interop';

import 'capture_visage.dart';

/// Fonction JavaScript définie dans web/face_auth.js.
@JS('faceAuthCapturer')
external JSPromise<JSString?> _faceAuthCapturer(JSString titre, JSString sousTitre);

const bool captureVisageDisponible = true;

/// Ouvre la caméra, détecte le visage et renvoie son descripteur (128 nombres).
Future<CaptureVisage> capturerVisage(
    {required String titre, String sousTitre = ''}) async {
  try {
    final res = await _faceAuthCapturer(titre.toJS, sousTitre.toJS).toDart;
    if (res == null) return const CaptureVisage(); // annulée
    final m = jsonDecode(res.toDart) as Map<String, dynamic>;
    if (m['erreur'] != null) return CaptureVisage(erreur: m['erreur'] as String);
    final d = (m['descripteur'] as List)
        .map((x) => (x as num).toDouble())
        .toList(growable: false);
    return CaptureVisage(descripteur: d);
  } catch (e) {
    return CaptureVisage(erreur: 'Vérification faciale indisponible : $e');
  }
}
