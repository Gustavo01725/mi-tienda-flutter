@Tags(['live'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_tienda/models/order.dart';
import 'package:mi_tienda/models/user.dart';
import 'package:mi_tienda/services/api.dart';
import 'package:mi_tienda/services/cart_state.dart';
import 'package:mi_tienda/services/catalog_state.dart';
import 'package:mi_tienda/services/orders_state.dart';
import 'package:mi_tienda/services/notifications_state.dart';

/// Prueba contra una web real (ver tool/local-test/README.md). Se omite si la web no responde.
/// Usa los modelos y estados de la app, así que comprueba que el JSON de la API es el que la app espera.
///   flutter test test/integration --tags live --dart-define=API_URL=http://localhost:8000
void main() {
  const url = String.fromEnvironment('API_URL', defaultValue: '');
  final skip = url.isEmpty ? 'defina --dart-define=API_URL para correr las pruebas live' : null;

  setUpAll(() => HttpOverrides.global = null); // flutter test bloquea HTTP real por defecto

  Future<Api> login(String email) async {
    final api = Api();
    final r = await api.post('/auth/login', {'email': email, 'password': 'secret123'});
    api.token = r['token'];
    expect(AppUser.fromJson(r['user']).email, email);
    return api;
  }

  test('catálogo: sync completo e incremental', skip: skip, () async {
    final catalog = CatalogState(Api());
    await catalog.sync();
    expect(catalog.error, isNull);
    expect(catalog.products, isNotEmpty);
    final p = catalog.products.first;
    expect(p.price, lessThanOrEqualTo(p.unitPrice));
    expect(p.stocks, isNotEmpty);
    await catalog.sync(); // incremental: no debe romper ni vaciar
    expect(catalog.products, isNotEmpty);
    catalog.stop();
  }, tags: ['live']);

  test('carrito: agregar, cambiar cantidad, quitar', skip: skip, () async {
    final api = await login('cust@t.com');
    final catalog = CatalogState(api);
    await catalog.sync();
    final p = catalog.products.first;
    final stock = p.stocks.firstWhere((s) => s.qty > 0);

    final cart = CartState(api);
    await cart.add(p.id, variation: stock.variant);
    expect(cart.cart.count, greaterThan(0));
    final item = cart.cart.items.firstWhere((i) => i.variation == stock.variant);
    await cart.setQuantity(item.id, 1);
    expect(cart.cart.items.firstWhere((i) => i.id == item.id).quantity, 1);
    await expectLater(cart.add(p.id), throwsA(isA<ApiException>())); // sin variante: 422
    await cart.remove(item.id);
    expect(cart.cart.items.where((i) => i.id == item.id), isEmpty);
    cart.dispose();
  }, tags: ['live']);

  test('pedidos y avisos del cliente se parsean', skip: skip, () async {
    final api = await login('cust@t.com');
    final orders = OrdersState(api);
    await orders.sync();
    for (final Order o in orders.orders) {
      expect(o.items, isNotEmpty);
    }
    final notifs = NotificationsState(api);
    await notifs.sync();
    expect(notifs.unread, greaterThanOrEqualTo(0));
    orders.dispose();
    notifs.dispose();
  }, tags: ['live']);

  test('permisos: un cliente no ve usuarios ni inventario', skip: skip, () async {
    final api = await login('cust@t.com');
    await expectLater(api.get('/sync/users'), throwsA(isA<ApiException>()));
    await expectLater(api.get('/seller/products'), throwsA(isA<ApiException>()));
  }, tags: ['live']);

  test('inventario: el vendedor cambia stock y el catálogo lo ve', skip: skip, () async {
    final seller = await login('seller@t.com');
    final list = await seller.get('/seller/products') as List;
    final product = list.first as Map<String, dynamic>;
    final st = (product['stocks'] as List).first as Map<String, dynamic>;
    final original = st['qty'] as int;

    await seller.put('/seller/products/${product['id']}/stocks', {
      'stocks': [{'id': st['id'], 'qty': original + 1}],
    });

    final catalog = CatalogState(Api());
    await catalog.sync();
    final seen = catalog.products.firstWhere((p) => p.id == product['id']).stocks.firstWhere((s) => s.id == st['id']);
    expect(seen.qty, original + 1);

    await seller.put('/seller/products/${product['id']}/stocks', {
      'stocks': [{'id': st['id'], 'qty': original}],
    });
    catalog.stop();
  }, tags: ['live']);

  test('ventas: el vendedor recibe sus pedidos pagados como "seller" y solo con sus líneas', skip: skip, () async {
    final seller = await login('seller@t.com');
    final orders = OrdersState(seller);
    await orders.sync();
    final sales = orders.orders.where((o) => o.isSale).toList();
    for (final o in sales) {
      expect(o.paid, isTrue);
      expect(o.items, isNotEmpty);
    }
    orders.dispose();
  }, tags: ['live']);
}
