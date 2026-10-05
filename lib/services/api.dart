import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  final String message;

  /// Código HTTP de la respuesta; null si no hubo respuesta (sin red, timeout).
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}

class Api {
  String? token;

  /// Se llama cuando el servidor rechaza el token (401): sesión cerrada desde la web, token revocado...
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final sentWithToken = token;
    final http.Response r;
    try {
      r = await call().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Sin conexión con el servidor');
    }

    // Laravel responde JSON sin charset: se decodifica como UTF-8 explícitamente. Un proxy o un
    // error del servidor puede devolver HTML; eso no debe escapar como FormatException.
    dynamic body;
    if (r.bodyBytes.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(r.bodyBytes));
      } on FormatException {
        if (r.statusCode >= 200 && r.statusCode < 300) {
          throw ApiException('Respuesta inválida del servidor', statusCode: r.statusCode);
        }
      }
    }

    if (r.statusCode >= 200 && r.statusCode < 300) return body;

    // Solo si el token rechazado sigue siendo el actual (no una petición vieja de otra sesión).
    if (r.statusCode == 401 && sentWithToken != null && sentWithToken == token) onUnauthorized?.call();

    if (body is Map && body['errors'] is Map && (body['errors'] as Map).isNotEmpty) {
      final first = (body['errors'] as Map).values.first;
      throw ApiException(first is List && first.isNotEmpty ? '${first.first}' : '$first', statusCode: r.statusCode);
    }
    final msg = body is Map && body['message'] is String && (body['message'] as String).isNotEmpty
        ? body['message'] as String
        : _fallback(r.statusCode);
    throw ApiException(msg, statusCode: r.statusCode);
  }

  static String _fallback(int code) => switch (code) {
        401 => 'Tu sesión expiró. Vuelve a iniciar sesión.',
        403 => 'No tienes permiso para hacer esto.',
        404 => 'No encontrado.',
        429 => 'Demasiados intentos. Espera un minuto.',
        >= 500 => 'Error del servidor ($code). Intenta de nuevo.',
        _ => 'Error $code',
      };

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$apiUrl/api$path').replace(queryParameters: q);

  Future<dynamic> get(String path, [Map<String, String>? q]) => _send(() => http.get(_u(path, q), headers: _headers));
  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> put(String path, Object body) =>
      _send(() => http.put(_u(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> delete(String path, [Object? body]) =>
      _send(() => http.delete(_u(path), headers: _headers, body: body == null ? null : jsonEncode(body)));
}
