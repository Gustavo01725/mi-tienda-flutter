import 'package:flutter_test/flutter_test.dart';
import 'package:mi_tienda/models/product.dart';

void main() {
  test('Product.fromJson lee precio, stock y variantes', () {
    final p = Product.fromJson({
      'id': 1, 'name': 'Zapatilla', 'thumbnail': 'x', 'unit_price': 100, 'price': 90.0, 'discount': 10,
      'total_stock': 3, 'low_stock_qty': 5,
      'stocks': [{'id': 1, 'size': '40', 'color': 'negro', 'variant': '40-negro', 'price': 90, 'qty': 3}],
    });
    expect(p.price, 90.0);
    expect(p.lowStock, isTrue);
    expect(p.stocks.single.variant, '40-negro');
  });
}
