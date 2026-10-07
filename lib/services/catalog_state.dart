import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/category.dart';
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

  /// Categorías activas (con imagen y nº de productos), para "Categorías" y la portada.
  List<ShopCategory> categories = [];
  int _ticks = 0;

  ShopCategory? categoryById(int? id) => id == null ? null : categories.where((c) => c.id == id).firstOrNull;

  Future<void> loadCategories() async {
    try {
      final r = await api.get('/categories') as List;
      categories = r.map((j) => ShopCategory.fromJson(j)).toList();
      _changed();
    } on ApiException {
      // se reintenta en el siguiente ciclo
    }
  }

  void start() {
    stop();
    sync();
    loadCategories();
    // Las categorías cambian poco: se refrescan cada ~minuto, los productos en cada ciclo.
    _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) {
      sync();
      if (++_ticks % 12 == 0 || categories.isEmpty) loadCategories();
    });
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
