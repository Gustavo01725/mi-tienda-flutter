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

  /// Se llama cuando cambia la sesión.
  void setLoggedIn(bool loggedIn) {
    if (loggedIn == _active) return;
    _active = loggedIn;
    _timer?.cancel();
    if (loggedIn) {
      refresh();
      _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) => refresh());
    } else {
      cart = Cart.empty();
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      cart = Cart.fromJson(await api.get('/cart'));
      notifyListeners();
    } on ApiException {
      // red caída: se conserva el último carrito
    }
  }

  Future<void> _mutate(Future<dynamic> Function() call) async {
    cart = Cart.fromJson(await call());
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
