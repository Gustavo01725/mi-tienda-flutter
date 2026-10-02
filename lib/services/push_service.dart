import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';

/// Push con Firebase Cloud Messaging. Es opcional: si el proyecto no tiene `google-services.json`
/// (o el usuario niega el permiso), [init] devuelve false y la app sigue con los avisos por
/// sincronización. Con la app cerrada o en segundo plano, Android muestra solo el push (el bloque
/// `notification` del mensaje); no hace falta handler de fondo.
class PushService {
  final Api api;
  PushService(this.api);

  String? _token;
  bool _started = false;

  /// True cuando FCM está operativo y registrado para el usuario actual.
  bool active = false;

  Future<bool> init() async {
    if (_started) return active;
    _started = true;
    try {
      await Firebase.initializeApp();
      final fcm = FirebaseMessaging.instance;
      final perm = await fcm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return false;

      _token = await fcm.getToken();
      if (_token == null) return false;
      await _register(_token!);
      fcm.onTokenRefresh.listen((t) {
        _token = t;
        _register(t);
      });
      active = true;
    } catch (e) {
      debugPrint('Push desactivado: $e');
      active = false;
    }
    return active;
  }

  Future<void> _register(String token) async {
    try {
      await api.post('/devices', {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
    } catch (_) {
      // se reintenta al siguiente inicio de sesión / refresh del token
    }
  }

  /// Al cerrar sesión el teléfono deja de recibir los avisos de esa cuenta.
  Future<void> unregister() async {
    final t = _token;
    if (t == null) return;
    try {
      await api.delete('/devices', {'token': t});
    } catch (_) {}
    _started = false;
    active = false;
  }
}
