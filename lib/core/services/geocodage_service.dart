import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Résultat d'un géocodage : position et adresse normalisée renvoyée par Nominatim.
typedef PositionAdresse = ({double latitude, double longitude, String adresse});

/// Géocodage via l'API REST Nominatim (OpenStreetMap), sans clé API.
/// Politique d'utilisation respectée : User-Agent identifiant l'application,
/// une requête par seconde au maximum (toutes instances confondues).
/// Hors connexion ou en cas d'erreur : renvoie null, [derniereErreur] explique pourquoi.
class GeocodageService {
  static const String _hote = 'nominatim.openstreetmap.org';
  static const Duration _delai = Duration(seconds: 10);
  static const Duration _intervalle = Duration(seconds: 1);
  static const Map<String, String> _entetes = {
    'User-Agent': 'TravelPlatform-ESPRIT/1.0',
    'Accept': 'application/json',
  };

  /// Créneau de la prochaine requête autorisée (partagé par toutes les instances).
  static DateTime? _prochainCreneau;

  final http.Client? _client;

  /// Message de la dernière erreur (null si le dernier appel a réussi).
  String? derniereErreur;

  /// [client] : injectable pour les tests ; sinon un client est créé à chaque appel.
  GeocodageService({http.Client? client}) : _client = client;

  /// Adresse -> position (recherche limitée à la Tunisie, premier résultat).
  Future<PositionAdresse?> chercherAdresse(String texte) async {
    final requete = texte.trim();
    if (requete.length < 3) {
      derniereErreur = 'Saisissez une adresse plus précise';
      return null;
    }
    final json = await _get('/search', {
      'q': requete,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'tn',
      'accept-language': 'fr',
    });
    if (json == null) return null;
    if (json is! List || json.isEmpty) {
      derniereErreur = 'Adresse introuvable';
      return null;
    }
    final premier = json.first;
    if (premier is! Map) {
      derniereErreur = 'Réponse inattendue du service';
      return null;
    }
    final lat = double.tryParse('${premier['lat']}');
    final lon = double.tryParse('${premier['lon']}');
    if (lat == null || lon == null) {
      derniereErreur = 'Réponse inattendue du service';
      return null;
    }
    return (
      latitude: lat,
      longitude: lon,
      adresse: (premier['display_name'] as String?) ?? requete,
    );
  }

  /// Position -> adresse lisible (géocodage inverse).
  Future<String?> adresseDepuisPosition(double lat, double lng) async {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      derniereErreur = 'Coordonnées invalides';
      return null;
    }
    final json = await _get('/reverse', {
      'lat': '$lat',
      'lon': '$lng',
      'format': 'json',
      'accept-language': 'fr',
    });
    if (json == null) return null;
    final adresse = json is Map ? json['display_name'] : null;
    if (adresse is! String || adresse.isEmpty) {
      derniereErreur = 'Aucune adresse à cette position';
      return null;
    }
    return adresse;
  }

  /// GET avec limite de débit, délai de 10 s et gestion des erreurs réseau.
  Future<Object?> _get(String chemin, Map<String, String> parametres) async {
    derniereErreur = null;
    await _attendreSonTour();
    final client = _client ?? http.Client();
    try {
      final reponse = await client
          .get(Uri.https(_hote, chemin, parametres), headers: _entetes)
          .timeout(_delai);
      if (reponse.statusCode == 429) {
        derniereErreur = 'Service de cartographie saturé, réessayez dans un instant';
        return null;
      }
      if (reponse.statusCode != 200) {
        derniereErreur = 'Service de cartographie indisponible (${reponse.statusCode})';
        return null;
      }
      return jsonDecode(utf8.decode(reponse.bodyBytes));
    } on TimeoutException {
      derniereErreur = 'Le service ne répond pas (délai de 10 s dépassé)';
    } on FormatException {
      derniereErreur = 'Réponse illisible du service';
    } catch (_) {
      // SocketException, ClientException… : pas de réseau.
      derniereErreur = 'Pas de connexion internet : saisissez les coordonnées à la main';
    } finally {
      if (_client == null) client.close();
    }
    return null;
  }

  /// Réserve le prochain créneau (1 requête / seconde) puis attend qu'il arrive.
  /// La réservation est synchrone : deux appels simultanés obtiennent deux créneaux distincts.
  static Future<void> _attendreSonTour() async {
    final maintenant = DateTime.now();
    final creneau = (_prochainCreneau == null || _prochainCreneau!.isBefore(maintenant))
        ? maintenant
        : _prochainCreneau!;
    _prochainCreneau = creneau.add(_intervalle);
    final attente = creneau.difference(maintenant);
    if (attente > Duration.zero) await Future<void>.delayed(attente);
  }
}
