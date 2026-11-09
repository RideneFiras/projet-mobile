import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client HTTP générique pour une API REST (chapitre 7).
///
/// Émulateur Android : "localhost" de votre PC = 10.0.2.2
/// Téléphone réel    : utilisez l'IP locale du PC (ex : 192.168.1.10).
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// À modifier selon votre backend.
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  static const Duration _timeout = Duration(seconds: 15);

  Future<dynamic> get(String endpoint) async {
    final res = await http
        .get(Uri.parse('$baseUrl$endpoint'), headers: _headers)
        .timeout(_timeout);
    return _traiter(res);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse('$baseUrl$endpoint'),
            headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _traiter(res);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final res = await http
        .put(Uri.parse('$baseUrl$endpoint'),
            headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _traiter(res);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final res = await http
        .patch(Uri.parse('$baseUrl$endpoint'),
            headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _traiter(res);
  }

  Future<dynamic> delete(String endpoint) async {
    final res = await http
        .delete(Uri.parse('$baseUrl$endpoint'), headers: _headers)
        .timeout(_timeout);
    return _traiter(res);
  }

  dynamic _traiter(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }
}

class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);

  @override
  String toString() => 'Erreur API $code : $message';
}
