import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/dates.dart';
import 'models/voyage.dart';

class EmailService {
  static const String _serviceId = 'service_3b0nwft';
  static const String _templateId = 'template_xy9hhr7';
  static const String _publicKey = 'hctyA4WaPDUJa6ex_';

  static Future<bool> envoyerConfirmation({
    required String emailUtilisateur,
    required Voyage voyage,
    required double totalPrix,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': emailUtilisateur,
            'destination': voyage.destination,
            'total_price': totalPrix.toStringAsFixed(2),
            'date_debut': dateIso(voyage.dateDebut),
            'date_fin': dateIso(voyage.dateFin),
          },
        }),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}