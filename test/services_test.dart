import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mi_tienda/models/order.dart';
import 'package:mi_tienda/models/product.dart';
import 'package:mi_tienda/services/api.dart';
import 'package:mi_tienda/services/auth_state.dart';
import 'package:mi_tienda/services/cart_state.dart';
import 'package:mi_tienda/services/catalog_state.dart';
import 'package:mi_tienda/services/orders_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response json(Object body, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

Map<String, dynamic> cartJson(int count) => {
      'items': [
        if (count > 0)
          {'id': 1, 'product_id': 1, 'quantity': count, 'name': 'Camiseta', 'thumbnail': '', 'price': 18, 'available_stock': 5},
      ],
      'count': count, 'subtotal': 18.0 * count, 'shipping': 0, 'tax': 0, 'total': 18.0 * count,
    };

Map<String, dynamic> productJson(int id, {bool published = true, String updated = '2026-10-05T10:00:00+00:00'}) => {
      'id': id, 'name': 'P$id', 'thumbnail': '', 'unit_price': 20, 'price': 18, 'published': published, 'approved': true,
      'updated_at': updated,
      'stocks': [{'id': id, 'variant': 'M-negro', 'price': 20, 'final_price': 18, 'qty': 3}],
    };

void main() {
  group('Api', () {
    test('un error HTML del servidor llega como ApiException con su código, no como FormatException', () async {
      final api = Api();
      await http.runWithClient(() async {
        await expectLater(
          api.get('/x'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 502)),
        );
      }, () => MockClient((_) async => http.Response('<html>Bad gateway</html>', 502)));
    });

    test('los acentos llegan bien aunque el servidor no declare charset', () async {
      final api = Api();
      final r = await http.runWithClient(() => api.get('/x'),
          () => MockClient((_) async => http.Response.bytes(utf8.encode('{"name":"Añadir camión"}'), 200)));
      expect(r['name'], 'Añadir camión');
    });

    test('un 401 con el token actual avisa para cerrar sesión', () async {
      final api = Api()..token = 't1';
      var called = 0;
      api.onUnauthorized = () => called++;
      await http.runWithClient(() async {
        await expectLater(api.get('/cart'), throwsA(isA<ApiException>()));
      }, () => MockClient((_) async => json({'message': 'Unauthenticated.'}, 401)));
      expect(called, 1);
    });
  });

  group('AuthState.restore', () {
    test('un 500 al arrancar NO borra la sesión guardada', () async {
      SharedPreferences.setMockInitialValues({'token': 'abc'});
      final auth = AuthState(Api());
      await http.runWithClient(auth.restore, () => MockClient((_) async => http.Response('oops', 500)));
      expect((await SharedPreferences.getInstance()).getString('token'), 'abc');
      expect(auth.api.token, 'abc');
    });

    test('un 401 al arrancar sí borra el token', () async {
      SharedPreferences.setMockInitialValues({'token': 'abc'});
      final auth = AuthState(Api());
      await http.runWithClient(auth.restore, () => MockClient((_) async => json({'message': 'Unauthenticated.'}, 401)));
      expect((await SharedPreferences.getInstance()).getString('token'), isNull);
      expect(auth.user, isNull);
    });
  });

  group('CartState', () {
    test('un refresco lento que salió antes de "añadir" no pisa el carrito nuevo', () async {
      final slowGet = Completer<http.Response>();
      final client = MockClient((req) async {
        if (req.method == 'GET') return slowGet.future;
        return json(cartJson(2));
      });
      await http.runWithClient(() async {
        final cart = CartState(Api()..token = 't');
        final refresh = cart.refresh(); // sale con el carrito viejo (1 unidad)
        await cart.add(1, variation: 'M-negro');
        expect(cart.cart.count, 2);
        slowGet.complete(json(cartJson(1)));
        await refresh;
        expect(cart.cart.count, 2);
        cart.dispose();
      }, () => client);
    });

    test('tras cerrar sesión, una respuesta en vuelo no devuelve el carrito del usuario anterior', () async {
      final slowGet = Completer<http.Response>();
      await http.runWithClient(() async {
        final cart = CartState(Api()..token = 't');
        final refresh = cart.refresh();
        cart.setLoggedIn(true);
        cart.setLoggedIn(false);
        slowGet.complete(json(cartJson(3)));
        await refresh;
        expect(cart.cart.count, 0);
        cart.dispose();
      }, () => MockClient((_) => slowGet.future));
    });
  });

  group('OrdersState', () {
    test('la respuesta de la sesión anterior no se queda ni deja su cursor', () async {
      final first = Completer<http.Response>();
      final requests = <Uri>[];
      final client = MockClient((req) async {
        requests.add(req.url);
        if (requests.length == 1) return first.future;
        return json({'server_time': '2026-10-05T10:00:00+00:00', 'changed': []});
      });
      await http.runWithClient(() async {
        final orders = OrdersState(Api()..token = 't');
        orders.setLoggedIn(true); // usuario A: petición 1 (lenta)
        orders.setLoggedIn(false);
        orders.setLoggedIn(true); // usuario B: petición 2, sin cursor
        first.complete(json({
          'server_time': '2026-10-05T12:00:00+00:00',
          'changed': [
            {'id': 9, 'user_id': 1, 'code': 'A', 'payment_status': 'paid', 'grand_total': 5, 'items': []}
          ],
        }));
        await Future<void>.delayed(Duration.zero);
        await orders.sync(); // petición 3: debe ir sin el cursor de A
        expect(orders.orders, isEmpty);
        expect(requests[1].queryParameters.containsKey('since'), isFalse);
        expect(requests.last.queryParameters['since'], '2026-10-05T10:00:00+00:00');
        orders.dispose();
      }, () => client);
    });
  });

  group('CatalogState', () {
    test('editar un producto y ocultarlo lo saca del catálogo público', () async {
      final catalog = CatalogState(Api());
      catalog.apply(Product.fromJson(productJson(1)));
      expect(catalog.byId(1), isNotNull);
      catalog.apply(Product.fromJson(productJson(1, published: false)));
      expect(catalog.byId(1), isNull);
    });

    test('un producto repetido sin cambios no provoca redibujado', () async {
      var notified = 0;
      final body = {'server_time': 'x', 'changed': [productJson(1)], 'active_ids': [1]};
      await http.runWithClient(() async {
        final catalog = CatalogState(Api())..addListener(() => notified++);
        await catalog.sync();
        await catalog.sync();
        expect(notified, 1);
        catalog.stop();
      }, () => MockClient((_) async => json(body)));
    });
  });

  test('modelos: precio final por variante y rol del pedido', () {
    expect(Product.fromJson(productJson(1)).stocks.single.finalPrice, 18);
    final o = Order.fromJson({'id': 1, 'user_id': 2, 'role': 'seller', 'payment_status': 'paid', 'grand_total': 10, 'items': []});
    expect(o.isSale, isTrue);
  });
}
