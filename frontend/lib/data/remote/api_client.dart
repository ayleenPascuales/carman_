import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';

/// Small HTTP facade with consistent timeouts and error translation.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    return _send(() => _client.get(uri, headers: _headers(token)));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    String? token,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(
      () => _client.post(
        uri,
        headers: _headers(token),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      timeout: timeout,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(
      () => _client.patch(
        uri,
        headers: _headers(token),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(
      () => _client.put(
        uri,
        headers: _headers(token),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
    );
  }

  Future<List<int>> getBytes(String path, {required String token}) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await _client.get(uri, headers: {
        'Accept': 'application/pdf',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode == 401) {
        throw const AuthException('La sesión expiró.', code: 'http_401');
      }
      if (response.statusCode == 403) {
        throw const AuthException('No tienes permiso para ver este archivo.', code: 'http_403');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppException('No se pudo descargar el archivo.',
            code: 'http_${response.statusCode}');
      }
      if (!response.headers['content-type'].toString().toLowerCase().contains('application/pdf')) {
        throw const AppException('El archivo recibido no es un PDF.',
            code: 'invalid_response');
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const NetworkException(isTimeout: true);
    } on http.ClientException {
      throw const NetworkException();
    }
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(() => _client.delete(uri, headers: _headers(token)));
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final response = await request().timeout(timeout);
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return payload;
      }

      final message =
          _extractMessage(payload) ??
          'La operación no pudo completarse (${response.statusCode}).';
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AuthException(message, code: 'http_${response.statusCode}');
      }
      throw AppException(message, code: 'http_${response.statusCode}');
    } on TimeoutException {
      throw const NetworkException(isTimeout: true);
    } on http.ClientException {
      // Las URL de cercanía pueden incluir coordenadas: nunca registrarlas.
      throw const NetworkException();
    } on FormatException {
      throw const AppException(
        'La respuesta del servidor no tiene el formato esperado.',
        code: 'invalid_response',
      );
    }
  }

  String? _extractMessage(Map<String, dynamic> payload) {
    final message = payload['message'] ?? payload['error'];
    if (message is String && message.isNotEmpty) return message;
    if (message is List && message.isNotEmpty) return '${message.first}';
    return null;
  }

  void dispose() => _client.close();
}
