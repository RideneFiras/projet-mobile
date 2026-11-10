import 'capture_visage.dart';

/// Android / iOS / tests : la capture faciale n'existe que dans la version web.
const bool captureVisageDisponible = false;

Future<CaptureVisage> capturerVisage(
        {required String titre, String sousTitre = ''}) async =>
    const CaptureVisage(
        erreur: 'La vérification faciale est disponible sur la version web.');
