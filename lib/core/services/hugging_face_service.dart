import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'gemini_service.dart';

/// Une étiquette renvoyée par un modèle de vision (classe + confiance 0 à 1).
typedef EtiquetteImage = ({String label, double score});

/// Client de l'API d'inférence Hugging Face pour l'analyse d'images
/// (dommages sur un véhicule, photo générée par IA…).
/// Clé : --dart-define=HF_API_KEY=... ; adresse modifiable par HF_API_URL.
class HuggingFaceService {
  static const String _cleDefinie = String.fromEnvironment('HF_API_KEY');
  static const String _urlDefinie = String.fromEnvironment('HF_API_URL',
      defaultValue: 'https://router.huggingface.co/hf-inference/models');
  static const Duration _delai = Duration(seconds: 10);

  final http.Client? _client;
  final String _cle;
  final String _url;

  HuggingFaceService({http.Client? client, String? cle, String? url})
      : _client = client,
        _cle = cle ?? _cleDefinie,
        _url = url ?? _urlDefinie;

  bool get configure => _cle.isNotEmpty;

  /// Télécharge une image (photo enregistrée par URL). Null si impossible.
  Future<Uint8List?> telecharger(String adresse) async {
    if (!adresse.startsWith('http')) return null;
    final client = _client ?? http.Client();
    try {
      final r = await client.get(Uri.parse(adresse)).timeout(_delai);
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Envoie l'image au [modele] et renvoie ses étiquettes, de la plus probable à la moins probable.
  /// Fonctionne pour les modèles de classification et de détection d'objets.
  Future<List<EtiquetteImage>> analyser(Uint8List image, {required String modele}) async {
    if (!configure) {
      throw const IaException(
          'Analyse d\'image non configurée : ajoutez --dart-define=HF_API_KEY=...');
    }
    final client = _client ?? http.Client();
    try {
      final r = await client
          .post(Uri.parse('$_url/$modele'),
              headers: {
                'Authorization': 'Bearer $_cle',
                'Content-Type': 'application/octet-stream',
              },
              body: image)
          .timeout(_delai);
      if (r.statusCode == 503) {
        throw const IaException('Le modèle démarre côté Hugging Face : réessayez dans 30 s.');
      }
      if (r.statusCode == 401 || r.statusCode == 403) {
        throw const IaException('Clé Hugging Face refusée. Vérifiez HF_API_KEY.');
      }
      if (r.statusCode != 200) {
        throw IaException('Analyse impossible (code ${r.statusCode}).');
      }
      final json = jsonDecode(utf8.decode(r.bodyBytes));
      if (json is! List) throw const IaException('Réponse du modèle illisible.');
      final etiquettes = <EtiquetteImage>[
        for (final e in json)
          if (e is Map && e['label'] is String && e['score'] is num)
            (label: e['label'] as String, score: (e['score'] as num).toDouble()),
      ]..sort((a, b) => b.score.compareTo(a.score));
      return etiquettes;
    } on TimeoutException {
      throw const IaException('Le service d\'analyse ne répond pas (10 s).');
    } on IaException {
      rethrow;
    } catch (_) {
      throw const IaException('Pas de connexion internet : analyse indisponible.');
    } finally {
      if (_client == null) client.close();
    }
  }
}
