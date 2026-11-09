import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/utils/dates.dart';
import 'models/itineraire.dart';
import 'models/voyage.dart';

class VoyageIaException implements Exception {
  final String message;
  const VoyageIaException(this.message);
  @override
  String toString() => message;
}

/// Service d'itinéraires basé sur Google Gemini (Gratuit).
class VoyageIaService {
  static const String _cle = String.fromEnvironment('GEMINI_API_KEY');

  static bool get configure => _cle.isNotEmpty;

  static const String _consigne =
      'Tu es un assistant de voyage. Réponds UNIQUEMENT par un objet JSON valide, '
      'sans texte autour, avec exactement ces clés : '
      '"jours" (liste d\'objets {"titre","matin","apres_midi","soir"}, '
      'chaque texte de 140 caractères maximum) et "conseil" (une phrase). '
      'N\'indique aucun prix. Écris en français.';

  Future<Itineraire> genererItineraire({
    required Voyage voyage,
    required Confort confort,
  }) async {
    if (!configure) {
      throw const VoyageIaException(
          'Clé API non configurée : ajoutez --dart-define=GEMINI_API_KEY=... au lancement.');
    }
    final demande = 'Destination : ${voyage.destination}. '
        'Du ${dateIso(voyage.dateDebut)} au ${dateIso(voyage.dateFin)} '
        '(${voyage.duree} jours). Niveau de séjour : ${confort.libelle}. '
        'Propose exactement ${voyage.duree} objets dans "jours", un par jour.';

    http.Response? reponse;
    // La clé part dans un en-tête (jamais dans l'URL : une URL finit dans les logs et les messages d'erreur).
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent',
    );

    // Tentatives multiples en cas de surcharge temporaire (503 / 429)
    for (int tentative = 0; tentative < 3; tentative++) {
      try {
        reponse = await http
            .post(
          url,
          headers: {
            'content-type': 'application/json',
            'x-goog-api-key': _cle,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': '$_consigne\n\n$demande'}
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
            }
          }),
        )
            .timeout(const Duration(seconds: 45));

        if (reponse.statusCode == 200) break;

        // Surcharge temporaire : on attend un peu avant de réessayer.
        if (reponse.statusCode == 503 || reponse.statusCode == 429) {
          await Future.delayed(Duration(seconds: 2 * (tentative + 1)));
          continue;
        }
        // Autre erreur (clé refusée, requête invalide) : inutile de réessayer.
        break;
      } catch (_) {
        if (tentative == 2) {
          throw const VoyageIaException(
              'Connexion impossible. Vérifiez internet et réessayez.');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    final code = reponse?.statusCode;
    if (code == 400 || code == 401 || code == 403) {
      throw VoyageIaException('Clé API refusée (code $code). Vérifiez la clé.');
    }
    if (reponse == null || code != 200) {
      throw VoyageIaException(
          'Service IA temporairement saturé (code ${code ?? 'inconnu'}). Réessayez dans un instant.');
    }

    try {
      final corps = jsonDecode(utf8.decode(reponse.bodyBytes)) as Map;
      final candidates = corps['candidates'] as List;
      final texte = candidates.first['content']['parts'].first['text'] as String;

      final debut = texte.indexOf('{');
      final fin = texte.lastIndexOf('}');
      if (debut < 0 || fin <= debut) throw const FormatException('pas de JSON');
      return Itineraire.depuisJson(jsonDecode(texte.substring(debut, fin + 1)));
    } catch (_) {
      throw const VoyageIaException(
          'Réponse illisible. Relancez la génération.');
    }
  }
}