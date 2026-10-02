import 'package:flutter_test/flutter_test.dart';
import 'package:mi_tienda/models/cart.dart';
import 'package:mi_tienda/models/order.dart';

void main() {
  test('Cart.fromJson lee ítems y totales', () {
    final c = Cart.fromJson({
      'items': [
        {'id': 1, 'product_id': 2, 'quantity': 2, 'name': 'Zapatilla', 'thumbnail': 'x', 'variation': '40-negro',
         'variant_label': 'Talla 40 · Negro', 'price': 45.5, 'available_stock': 3},
      ],
      'count': 2, 'subtotal': 91, 'shipping': 5, 'tax': 0, 'total': 96,
    });
    expect(c.items.single.variation, '40-negro');
    expect(c.total, 96.0);
  });

  test('Order.fromJson lee estado de pago y entrega', () {
    final o = Order.fromJson({
      'id': 7, 'user_id': 3, 'code': 'ORD-1', 'status': 'pagado', 'payment_status': 'paid',
      'delivery_status': 'warehouse', 'grand_total': 96, 'shipping_address': {'city': 'Quito'}, 'items': [],
    });
    expect(o.paid, isTrue);
    expect(o.deliveryLabel, 'En almacén');
    expect(o.shipping['city'], 'Quito');
  });
}
