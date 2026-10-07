import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api.dart';

class AuthState extends ChangeNotifier {
  final Api api;

  AuthState(this.api) {
    // Token rechazado por el servidor: se cierra la sesión local sin volver a llamar a la API.
    api.onUnauthorized = () {
      if (user != null) _clear();
    };
  }

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
        // Solo un 401 significa token inválido. Sin red o con el servidor caído (5xx) el token se
        // conserva: borrarlo cerraría la sesión del usuario por un fallo pasajero.
        if (e.statusCode == 401) {
          api.token = null;
          await p.remove('token');
        }
      }
    }
    ready = true;
    notifyListeners();
  }

  /// [remember] = "Recordarme": si no se marca, la sesión dura hasta cerrar la app.
  Future<void> _store(Map<String, dynamic> r, {bool remember = true}) async {
    api.token = r['token'];
    user = AppUser.fromJson(r['user']);
    final p = await SharedPreferences.getInstance();
    if (remember) {
      await p.setString('token', api.token!);
    } else {
      await p.remove('token');
    }
    notifyListeners();
  }

  Future<void> login(String email, String password, {bool remember = true}) async => _store(
        await api.post('/auth/login', {'email': email, 'password': password, 'device': 'flutter'}),
        remember: remember,
      );

  Future<void> register(String name, String email, String password, {String? phone}) async => _store(await api.post(
        '/auth/register',
        {'name': name, 'email': email, 'password': password, if (phone != null && phone.isNotEmpty) 'phone': phone},
      ));

  /// Datos actualizados desde "Mi perfil".
  void updateUser(AppUser u) {
    user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await beforeLogout?.call();
    } catch (_) {}
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await _clear();
  }

  Future<void> _clear() async {
    api.token = null;
    user = null;
    notifyListeners();
    await (await SharedPreferences.getInstance()).remove('token');
  }
}
