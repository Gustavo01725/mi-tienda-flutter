class OrderItem {
  final String name, thumbnail, variantLabel;
  final double price;
  final int quantity;
  OrderItem.fromJson(Map<String, dynamic> j)
      : name = j['name'] ?? '',
        thumbnail = j['thumbnail'] ?? '',
        variantLabel = j['variant_label'] ?? '',
        price = (j['price'] as num).toDouble(),
        quantity = j['quantity'];
}

class Order {
  final int id, userId;
  final String code, status, paymentStatus, deliveryStatus;
  final double total;
  final List<OrderItem> items;
  final Map<String, dynamic> shipping;
  final DateTime? createdAt;

  Order.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        userId = j['user_id'] ?? 0,
        code = j['code'] ?? '#${j['id']}',
        status = j['status'] ?? '',
        paymentStatus = j['payment_status'] ?? 'unpaid',
        deliveryStatus = j['delivery_status'] ?? 'pending',
        total = (j['grand_total'] as num).toDouble(),
        items = (j['items'] as List).map((e) => OrderItem.fromJson(e)).toList(),
        shipping = Map<String, dynamic>.from(j['shipping_address'] is Map ? j['shipping_address'] : {}),
        createdAt = DateTime.tryParse(j['created_at'] ?? '');

  bool get paid => paymentStatus == 'paid';

  String get deliveryLabel => const {
        'pending': 'Pendiente',
        'confirmed': 'Confirmado',
        'warehouse': 'En almacén',
        'on_the_way': 'En camino',
        'delivered': 'Entregado',
      }[deliveryStatus] ??
      deliveryStatus;
}
