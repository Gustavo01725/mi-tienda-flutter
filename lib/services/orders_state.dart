import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/order.dart';
import 'api.dart';

/// Pedidos del usuario (y los de sus productos si vende), con sincronización incremental.
class OrdersState extends ChangeNotifier {
  final Api api;
  OrdersState(this.api);

  final Map<int, Order> _orders = {};
  String? _since;
  Timer? _timer;
  bool _active = false, _busy = false;

  /// Ver CartState._session: una respuesta de la sesión anterior no puede repoblar la lista ni
  /// dejar su cursor, o el siguiente usuario solo recibiría los cambios recientes, no sus pedidos.
  int _session = 0;

  List<Order> get orders => _orders.values.toList()..sort((a, b) => b.id.compareTo(a.id));

  Order? byId(int id) => _orders[id];

  void setLoggedIn(bool loggedIn) {
    if (loggedIn == _active) return;
    _active = loggedIn;
    _session++;
    _timer?.cancel();
    _orders.clear();
    _since = null;
    _busy = false;
    if (loggedIn) {
      sync();
      _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) => sync());
    }
    notifyListeners();
  }

  Future<void> sync() async {
    if (_busy) return;
    _busy = true;
    final session = _session;
    try {
      final r = await api.get('/sync/orders', {'since': ?_since});
      if (session != _session) return;
      var dirty = false;
      for (final j in r['changed'] as List) {
        final o = Order.fromJson(j);
        final old = _orders[o.id];
        if (old != null && old.updatedAt != null && old.updatedAt == o.updatedAt) continue;
        _orders[o.id] = o;
        dirty = true;
      }
      _since = r['server_time'];
      if (dirty) notifyListeners();
    } on ApiException {
      // se reintenta en el siguiente ciclo
    } finally {
      if (session == _session) _busy = false;
    }
  }

  void apply(Order o) {
    _orders[o.id] = o;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
