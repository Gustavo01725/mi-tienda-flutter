import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/cart.dart';
import 'api.dart';

/// Carrito del usuario. Vive en el servidor (tabla `carts`, la misma de la web),
/// así que se refresca con el mismo ciclo que el catálogo: lo que se agrega en la
/// web aparece en la app y viceversa.
class CartState extends ChangeNotifier {
  final Api api;
  CartState(this.api);

  Cart cart = Cart.empty();
  Timer? _timer;
  bool _active = false;

  /// Cambia con cada sesión: la respuesta de una petición lanzada con la sesión anterior se descarta
  /// (si no, el carrito del usuario anterior reaparecería tras cerrar sesión).
  int _session = 0;

  /// Cambia con cada modificación hecha en la app: un refresco periódico que salió antes no puede
  /// pisar con datos viejos el resultado de "añadir" o "quitar".
  int _rev = 0;

  /// Se llama cuando cambia la sesión.
  void setLoggedIn(bool loggedIn) {
    if (loggedIn == _active) return;
    _active = loggedIn;
    _session++;
    _timer?.cancel();
    cart = Cart.empty();
    if (loggedIn) {
      refresh();
      _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) => refresh());
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    final session = _session, rev = _rev;
    try {
      final r = await api.get('/cart');
      if (session != _session || rev != _rev) return;
      cart = Cart.fromJson(r);
      notifyListeners();
    } on ApiException {
      // red caída: se conserva el último carrito
    }
  }

  Future<void> _mutate(Future<dynamic> Function() call) async {
    final session = _session;
    _rev++;
    final r = await call();
    if (session != _session) return;
    _rev++; // invalida también los refrescos que salieron mientras se esperaba esta respuesta
    cart = Cart.fromJson(r);
    notifyListeners();
  }

  Future<void> add(int productId, {String? variation, int quantity = 1}) => _mutate(() => api.post('/cart', {
        'product_id': productId,
        'quantity': quantity,
        if (variation != null && variation.isNotEmpty) 'variation': variation,
      }));

  Future<void> setQuantity(int itemId, int quantity) => _mutate(() => api.put('/cart/$itemId', {'quantity': quantity}));

  Future<void> remove(int itemId) => _mutate(() => api.delete('/cart/$itemId'));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
