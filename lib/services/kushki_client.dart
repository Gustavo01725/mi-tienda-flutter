import 'dart:convert';
import 'package:http/http.dart' as http;

class KushkiException implements Exception {
  final String message;
  KushkiException(this.message);
  @override
  String toString() => message;
}

/// Tokeniza la tarjeta directamente contra Kushki con el Public-Merchant-Id. Los datos de
/// la tarjeta no pasan por el servidor de la tienda: solo se envía el token resultante.
///
/// OJO: el endpoint y el cuerpo siguen el contrato público de Kushki
/// (POST /card/v1/tokens), pero no pude verificarlos contra su documentación ni contra el
/// ambiente UAT desde este entorno. Probar con credenciales de prueba antes de publicar.
class KushkiClient {
  final String publicId;
  final bool production;
  KushkiClient({required this.publicId, required this.production});

  String get _base => production ? 'https://api.kushkipagos.com' : 'https://api-uat.kushkipagos.com';

  Future<String> tokenize({
    required String name,
    required String number,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required double totalAmount,
  }) async {
    final http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('$_base/card/v1/tokens'),
            headers: {'Public-Merchant-Id': publicId, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'card': {
                'name': name,
                'number': number.replaceAll(RegExp(r'\s'), ''),
                'expiryMonth': expiryMonth.padLeft(2, '0'),
                'expiryYear': expiryYear.length == 4 ? expiryYear.substring(2) : expiryYear,
                'cvv': cvv,
              },
              'totalAmount': totalAmount,
              'currency': 'USD',
              'isDeferred': false,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw KushkiException('No se pudo contactar a Kushki');
    }
    dynamic body;
    try {
      body = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      body = null; // p. ej. una página de error HTML de un proxy
    }
    if (r.statusCode == 200 && body is Map && body['token'] is String) return body['token'];
    throw KushkiException(body is Map && body['message'] != null ? '${body['message']}' : 'Tarjeta rechazada (${r.statusCode})');
  }
}
