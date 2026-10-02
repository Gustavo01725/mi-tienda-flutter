import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/product.dart';
import 'api.dart';

/// Mantiene el catálogo en memoria y lo sincroniza con la web:
/// una carga completa inicial y luego cambios incrementales cada [syncSeconds].
class CatalogState extends ChangeNotifier {
  final Api api;
  CatalogState(this.api);

  final Map<int, Product> _items = {};
  String? _since;
  Timer? _timer;
  bool _busy = false;
  String? error;
  DateTime? lastSync;

  List<Product> get products => _items.values.toList()..sort((a, b) => b.id.compareTo(a.id));

  void start() {
    stop();
    sync();
    _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) => sync());
  }

  void stop() => _timer?.cancel();

  Future<void> sync() async {
    if (_busy) return;
    _busy = true;
    try {
      final r = await api.get('/sync/products', {if (_since != null) 'since': _since!});
      var dirty = false;
      for (final j in r['changed'] as List) {
        final p = Product.fromJson(j);
        _items[p.id] = p;
        dirty = true;
      }
      // Lo que ya no está activo en la web (borrado o despublicado) se quita de la app.
      final active = (r['active_ids'] as List).cast<int>().toSet();
      final before = _items.length;
      _items.removeWhere((id, _) => !active.contains(id));
      if (_items.length != before) dirty = true;
      _since = r['server_time'];
      lastSync = DateTime.now();
      if (error != null || dirty) {
        error = null;
        notifyListeners();
      }
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  /// Aplica un producto devuelto por una edición hecha desde la app, sin esperar al ciclo.
  void apply(Product p) {
    _items[p.id] = p;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
