import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/dates.dart';
import 'models/location_vehicule.dart';
import 'models/vehicule.dart';

/// E-mail de confirmation de location via l'API REST EmailJS.
/// Identifiants fournis au lancement, jamais écrits dans le code :
///   flutter run --dart-define=EMAILJS_SERVICE_ID=... \
///               --dart-define=EMAILJS_TEMPLATE_LOCATION=... \
///               --dart-define=EMAILJS_PUBLIC_KEY=...
/// Sans ces valeurs, rien n'est envoyé (renvoie false, aucune erreur).
/// Côté EmailJS : Account > Security > activer « Allow EmailJS API for non-browser applications ».
class LocationEmailService {
  static const String _url = 'https://api.emailjs.com/api/v1.0/email/send';
  static const Duration _delai = Duration(seconds: 10);

  static const String _serviceIdDefini = String.fromEnvironment('EMAILJS_SERVICE_ID');
  static const String _templateIdDefini = String.fromEnvironment('EMAILJS_TEMPLATE_LOCATION');
  static const String _cleDefinie = String.fromEnvironment('EMAILJS_PUBLIC_KEY');

  final http.Client? _client;
  final String _serviceId;
  final String _templateId;
  final String _clePublique;

  /// Les paramètres optionnels servent aux tests ; en production ils viennent de --dart-define.
  LocationEmailService({
    http.Client? client,
    String? serviceId,
    String? templateId,
    String? clePublique,
  })  : _client = client,
        _serviceId = serviceId ?? _serviceIdDefini,
        _templateId = templateId ?? _templateIdDefini,
        _clePublique = clePublique ?? _cleDefinie;

  /// Les trois identifiants sont renseignés.
  bool get configure =>
      _serviceId.isNotEmpty && _templateId.isNotEmpty && _clePublique.isNotEmpty;

  /// Paramètres envoyés au modèle EmailJS (variables {{to_email}}, {{nom_vehicule}}…).
  static Map<String, String> parametresModele({
    required String email,
    required LocationVehicule location,
    required String nomVehicule,
    required TypeVehicule typeVehicule,
  }) =>
      {
        'to_email': email,
        'nom_vehicule': nomVehicule,
        'type_vehicule': typeVehicule.libelle,
        'date_debut': dateIso(location.dateDebut),
        'date_fin': dateIso(location.dateFin),
        'prix_total': location.prixTotal.toStringAsFixed(2),
        'caution': location.caution.toStringAsFixed(2),
        'lieu_prise': location.lieuPrise ?? 'Non précisé',
      };

  /// Envoie la confirmation. Renvoie true si EmailJS a accepté l'e-mail ;
  /// false si non configuré, adresse vide, hors connexion, délai dépassé ou refus.
  Future<bool> envoyerConfirmation({
    required String email,
    required LocationVehicule location,
    required String nomVehicule,
    required TypeVehicule typeVehicule,
  }) async {
    if (!configure || email.trim().isEmpty) return false;
    final client = _client ?? http.Client();
    try {
      final reponse = await client
          .post(
            Uri.parse(_url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': _serviceId,
              'template_id': _templateId,
              'user_id': _clePublique,
              'template_params': parametresModele(
                email: email.trim(),
                location: location,
                nomVehicule: nomVehicule,
                typeVehicule: typeVehicule,
              ),
            }),
          )
          .timeout(_delai);
      return reponse.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (_) {
      // Pas de réseau ou service injoignable : la location reste enregistrée.
      return false;
    } finally {
      if (_client == null) client.close();
    }
  }
}
