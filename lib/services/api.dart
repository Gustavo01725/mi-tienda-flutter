import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  String? token;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final http.Response r;
    try {
      r = await call().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Sin conexión con el servidor');
    }
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    if (body is Map && body['errors'] is Map) {
      final first = (body['errors'] as Map).values.first;
      throw ApiException(first is List ? first.first.toString() : first.toString());
    }
    throw ApiException(body is Map && body['message'] != null ? body['message'] : 'Error ${r.statusCode}');
  }

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$apiUrl/api$path').replace(queryParameters: q);

  Future<dynamic> get(String path, [Map<String, String>? q]) => _send(() => http.get(_u(path, q), headers: _headers));
  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> put(String path, Object body) =>
      _send(() => http.put(_u(path), headers: _headers, body: jsonEncode(body)));
}
