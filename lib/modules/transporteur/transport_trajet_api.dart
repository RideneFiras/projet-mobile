import 'dart:async';
import 'dart:convert';

import '../../core/services/api_service.dart';

/// Point GPS : [lat, lon] tel qu'envoyé par le serveur.
class PointGeo {
  final double lat;
  final double lon;

  const PointGeo({required this.lat, required this.lon});

  factory PointGeo.depuisJson(List<dynamic> json) => PointGeo(
        lat: (json[0] as num).toDouble(),
        lon: (json[1] as num).toDouble(),
      );
}

/// Distance et durée d'un parcours (calculé ou estimé).
class Parcours {
  final double distanceKm;
  final int dureeMin;
  final List<PointGeo> trace;

  const Parcours({
    required this.distanceKm,
    required this.dureeMin,
    this.trace = const [],
  });

  factory Parcours.depuisJson(Map<String, dynamic> json) => Parcours(
        distanceKm: (json['distance_km'] as num).toDouble(),
        dureeMin: (json['duree_min'] as num).round(),
        trace: (json['trace'] as List? ?? const [])
            .whereType<List>()
            .map(PointGeo.depuisJson)
            .toList(),
      );
}

/// Itinéraire entre deux villes, tel que renvoyé par `POST /transport/itineraire`.
/// [estime] vaut vrai quand le serveur n'a pas pu interroger OpenRouteService :
/// la distance est alors calculée à partir des coordonnées, sans tracé routier.
class ItineraireTrajet {
  final String depart;
  final String arrivee;
  final bool estime;
  final Parcours recommande;
  final List<Parcours> alternatives;
  final String? avertissement;
  final PointGeo? pointDepart;
  final PointGeo? pointArrivee;

  const ItineraireTrajet({
    required this.depart,
    required this.arrivee,
    required this.estime,
    required this.recommande,
    required this.alternatives,
    this.avertissement,
    this.pointDepart,
    this.pointArrivee,
  });

  factory ItineraireTrajet.depuisJson(Map<String, dynamic> json) => ItineraireTrajet(
        depart: json['depart'] as String,
        arrivee: json['arrivee'] as String,
        estime: json['source'] != 'openrouteservice',
        recommande: Parcours.depuisJson(json['recommande'] as Map<String, dynamic>),
        alternatives: (json['alternatives'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Parcours.depuisJson)
            .toList(),
        avertissement: json['avertissement'] as String?,
        pointDepart: _point(json['points'], 'depart'),
        pointArrivee: _point(json['points'], 'arrivee'),
      );

  /// Point de départ ou d'arrivée, absent si le serveur est plus ancien.
  static PointGeo? _point(Object? points, String cle) {
    if (points is! Map) return null;
    final valeur = points[cle];
    return valeur is List && valeur.length >= 2 ? PointGeo.depuisJson(valeur) : null;
  }

}

/// Erreur à afficher à l'utilisateur (ville inconnue, serveur arrêté, réponse inattendue).
class ErreurTrajetApi implements Exception {
  final String message;

  const ErreurTrajetApi(this.message);

  @override
  String toString() => message;
}

/// Itinéraire d'un trajet, demandé au serveur applicatif.
///
/// Le serveur appelle OpenRouteService : l'application ne transmet
/// et ne reçoit aucune clé. Une ville inconnue (400) est expliquée ; une panne du
/// serveur est signalée sans bloquer le reste de l'écran.
class TrajetApiService {
  TrajetApiService._();

  static const String _itineraire = '/transport/itineraire';
  // L'itinéraire peut enchaîner géocodage et calcul côté serveur : délai plus long.
  static const Duration _delaiItineraire = Duration(seconds: 35);

  static Future<ItineraireTrajet> itineraire(String depart, String arrivee) async {
    final rep = await _appeler(_itineraire, {
      'depart': depart.trim(),
      'arrivee': arrivee.trim(),
    }, delai: _delaiItineraire);
    try {
      return ItineraireTrajet.depuisJson(rep);
    } on TypeError catch (_) {
      throw const ErreurTrajetApi('Réponse inattendue du serveur.');
    }
  }

  static Future<Map<String, dynamic>> _appeler(
    String endpoint,
    Map<String, dynamic> corps, {
    Duration? delai,
  }) async {
    try {
      final rep = await ApiService.instance.post(endpoint, corps, timeout: delai);
      if (rep is Map<String, dynamic>) return rep;
    } on ApiException catch (e) {
      // 404 : la route demandée n'existe pas sur le serveur qui répond. C'est en général
      // une ancienne version du serveur, encore ouverte sur le même port.
      if (e.code == 404) {
        throw const ErreurTrajetApi(
            'Itinéraire introuvable sur le serveur. Fermez l’ancienne fenêtre du serveur et relancez « node index.js ».');
      }
      throw ErreurTrajetApi(_messageServeur(
        e.message,
        repli: e.code == 400
            ? 'Demande refusée par le serveur.'
            : 'Service indisponible pour le moment (erreur ${e.code}).',
      ));
    } on TimeoutException catch (_) {
      throw const ErreurTrajetApi('Le serveur met trop de temps à répondre. Réessayez.');
    } on Exception catch (_) {
      // Le serveur ne répond pas à cette adresse : fenêtre fermée, serveur arrêté ou bloqué.
      throw ErreurTrajetApi(
          'Serveur injoignable (${ApiService.baseUrl}). Dans le dossier server, lancez « node index.js » et gardez cette fenêtre ouverte.');
    }
    throw const ErreurTrajetApi('Réponse inattendue du serveur.');
  }

  /// Le serveur répond `{ "erreur": "..." }` quand la demande est refusée ou qu'un
  /// service externe est indisponible. [repli] sert si le corps n'est pas lisible.
  static String _messageServeur(String corps, {required String repli}) {
    try {
      final json = jsonDecode(corps);
      if (json is Map && json['erreur'] is String) return json['erreur'] as String;
    } on FormatException catch (_) {
      // Corps non JSON : message de repli ci-dessous.
    }
    return repli;
  }
}
