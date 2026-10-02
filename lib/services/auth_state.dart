import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api.dart';

class AuthState extends ChangeNotifier {
  final Api api;
  AuthState(this.api);

  /// Se ejecuta antes de invalidar el token (p. ej. para desregistrar el push).
  Future<void> Function()? beforeLogout;

  AppUser? user;
  bool ready = false;

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    api.token = p.getString('token');
    if (api.token != null) {
      try {
        user = AppUser.fromJson(await api.get('/auth/me'));
      } on ApiException catch (e) {
        // Token revocado o inválido: sesión cerrada. Si solo falló la red, se conserva el token.
        if (!e.message.startsWith('Sin conexión')) {
          api.token = null;
          await p.remove('token');
        }
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _store(Map<String, dynamic> r) async {
    api.token = r['token'];
    user = AppUser.fromJson(r['user']);
    (await SharedPreferences.getInstance()).setString('token', api.token!);
    notifyListeners();
  }

  Future<void> login(String email, String password) async =>
      _store(await api.post('/auth/login', {'email': email, 'password': password, 'device': 'flutter'}));

  Future<void> register(String name, String email, String password) async =>
      _store(await api.post('/auth/register', {'name': name, 'email': email, 'password': password}));

  Future<void> logout() async {
    try {
      await beforeLogout?.call();
    } catch (_) {}
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    api.token = null;
    user = null;
    (await SharedPreferences.getInstance()).remove('token');
    notifyListeners();
  }
}
