import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur lisible renvoyée par les services d'IA (affichée telle quelle à l'utilisateur).
class IaException implements Exception {
  final String message;
  const IaException(this.message);

  @override
  String toString() => message;
}

/// Client Google Gemini (REST) partagé par les services d'IA des modules.
/// Clé : --dart-define=GEMINI_API_KEY=... (jamais dans le code).
/// Le modèle doit répondre en JSON ; la réponse est extraite et décodée.
/// Délai de 10 s par tentative, une seconde tentative si le service est saturé (429 / 503).
class GeminiService {
  static const String _cleDefinie = String.fromEnvironment('GEMINI_API_KEY');
  static const String _modeleDefini =
      String.fromEnvironment('GEMINI_MODELE', defaultValue: 'gemini-3.6-flash');
  static const Duration _delai = Duration(seconds: 10);

  final http.Client? _client;
  final String _cle;
  final String _modele;

  GeminiService({http.Client? client, String? cle, String? modele})
      : _client = client,
        _cle = cle ?? _cleDefinie,
        _modele = modele ?? _modeleDefini;

  bool get configure => _cle.isNotEmpty;

  /// Envoie [consigne] + [demande] et renvoie le JSON décodé (Map ou List).
  /// Lève [IaException] : non configuré, hors connexion, refus, réponse illisible.
  Future<Object?> genererJson({required String consigne, required String demande}) async {
    if (!configure) {
      throw const IaException(
          'IA non configurée : lancez l\'application avec --dart-define=GEMINI_API_KEY=...');
    }
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modele:generateContent');
    final corps = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$consigne\n\n$demande'},
          ],
        },
      ],
      'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.4},
    });

    final client = _client ?? http.Client();
    http.Response? reponse;
    try {
      for (var tentative = 0; tentative < 2; tentative++) {
        final http.Response r;
        try {
          r = await client
              .post(url,
                  headers: {'content-type': 'application/json', 'x-goog-api-key': _cle},
                  body: corps)
              .timeout(_delai);
        } on TimeoutException {
          throw const IaException('L\'IA ne répond pas (délai de 10 s dépassé). Réessayez.');
        } catch (_) {
          throw const IaException('Pas de connexion internet : fonction IA indisponible.');
        }
        reponse = r;
        // Service saturé : une seconde tentative après une pause.
        if ((r.statusCode == 429 || r.statusCode == 503) && tentative == 0) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        break;
      }
    } finally {
      if (_client == null) client.close();
    }

    final code = reponse?.statusCode;
    if (code == 400 || code == 401 || code == 403) {
      throw IaException('Clé IA refusée (code $code). Vérifiez GEMINI_API_KEY.');
    }
    if (reponse == null || code != 200) {
      throw IaException('Service IA indisponible (code ${code ?? '?'}). Réessayez plus tard.');
    }
    try {
      final json = jsonDecode(utf8.decode(reponse.bodyBytes)) as Map;
      final texte =
          ((json['candidates'] as List).first as Map)['content']['parts'][0]['text'] as String;
      return extraireJson(texte);
    } catch (_) {
      throw const IaException('Réponse de l\'IA illisible. Réessayez.');
    }
  }

  /// Extrait le premier objet ou tableau JSON d'un texte (le modèle ajoute parfois du texte).
  static Object? extraireJson(String texte) {
    final debutObjet = texte.indexOf('{');
    final debutListe = texte.indexOf('[');
    final estListe = debutListe >= 0 && (debutObjet < 0 || debutListe < debutObjet);
    final debut = estListe ? debutListe : debutObjet;
    final fin = texte.lastIndexOf(estListe ? ']' : '}');
    if (debut < 0 || fin <= debut) throw const FormatException('pas de JSON');
    return jsonDecode(texte.substring(debut, fin + 1));
  }
}
