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

  List<Order> get orders => _orders.values.toList()..sort((a, b) => b.id.compareTo(a.id));

  void setLoggedIn(bool loggedIn) {
    if (loggedIn == _active) return;
    _active = loggedIn;
    _timer?.cancel();
    if (loggedIn) {
      sync();
      _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) => sync());
    } else {
      _orders.clear();
      _since = null;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    if (_busy) return;
    _busy = true;
    try {
      final r = await api.get('/sync/orders', {if (_since != null) 'since': _since!});
      final changed = r['changed'] as List;
      for (final j in changed) {
        final o = Order.fromJson(j);
        _orders[o.id] = o;
      }
      _since = r['server_time'];
      if (changed.isNotEmpty) notifyListeners();
    } on ApiException {
      // se reintenta en el siguiente ciclo
    } finally {
      _busy = false;
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
