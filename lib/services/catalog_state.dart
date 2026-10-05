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
  List<Product>? _sorted;
  String? _since;
  Timer? _timer;
  bool _busy = false;
  String? error;
  DateTime? lastSync;

  /// Productos ordenados (más nuevos primero). Se cachea: lo leen varias pantallas en cada build.
  List<Product> get products => _sorted ??= (_items.values.toList()..sort((a, b) => b.id.compareTo(a.id)));

  Product? byId(int id) => _items[id];

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
      final r = await api.get('/sync/products', {'since': ?_since});
      var dirty = false;
      for (final j in r['changed'] as List) {
        final p = Product.fromJson(j);
        // El servidor repite los cambios de los últimos segundos (margen del cursor): si no cambió,
        // no se redibuja nada.
        final old = _items[p.id];
        if (old != null && old.updatedAt != null && old.updatedAt == p.updatedAt) continue;
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
        _changed();
      }
    } on ApiException catch (e) {
      if (error != e.message) {
        error = e.message;
        _changed();
      }
    } finally {
      _busy = false;
    }
  }

  /// Aplica un producto devuelto por una edición hecha desde la app, sin esperar al ciclo.
  /// Uno oculto o sin aprobar no pertenece al catálogo público.
  void apply(Product p) {
    if (p.published && p.approved) {
      _items[p.id] = p;
    } else {
      _items.remove(p.id);
    }
    _changed();
  }

  void _changed() {
    _sorted = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
