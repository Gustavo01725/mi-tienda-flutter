import 'variant_parts.dart';

class CartItem {
  final int id, productId, quantity;
  final String name, thumbnail, variantLabel;
  final String? variation;
  final double price;
  final int? availableStock;
  final double shippingCost;
  final VariantParts parts;

  CartItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        productId = j['product_id'],
        quantity = j['quantity'],
        name = j['name'] ?? '',
        thumbnail = j['thumbnail'] ?? '',
        variantLabel = j['variant_label'] ?? '',
        variation = j['variation'],
        price = (j['price'] as num).toDouble(),
        availableStock = j['available_stock'],
        shippingCost = ((j['shipping_cost'] ?? 0) as num).toDouble(),
        parts = VariantParts.fromJson(j['variant_parts']);

  double get subtotal => price * quantity;
}

class Cart {
  final List<CartItem> items;
  final int count;
  final double subtotal, shipping, tax, total;

  Cart.empty()
      : items = const [],
        count = 0,
        subtotal = 0,
        shipping = 0,
        tax = 0,
        total = 0;

  Cart.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List).map((e) => CartItem.fromJson(e)).toList(),
        count = j['count'],
        subtotal = (j['subtotal'] as num).toDouble(),
        shipping = (j['shipping'] as num).toDouble(),
        tax = (j['tax'] as num).toDouble(),
        total = (j['total'] as num).toDouble();
}
