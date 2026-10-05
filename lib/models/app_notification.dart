class AppNotification {
  final String id, message, type;
  final int? orderId;
  final bool read;
  final DateTime? createdAt;

  AppNotification.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        message = j['message'] ?? '',
        type = j['type'] ?? '',
        orderId = j['order_id'],
        read = j['read'] ?? false,
        createdAt = DateTime.tryParse(j['created_at'] ?? '');

  AppNotification._(this.id, this.message, this.type, this.orderId, this.read, this.createdAt);

  AppNotification copyRead() => AppNotification._(id, message, type, orderId, true, createdAt);

  String get title => switch (type) {
        'SellerNewOrderNotification' => 'Nueva venta',
        'OrderArrivedWarehouseNotification' => 'Pedido en almacén',
        'ShopStatusUpdatedNotification' => 'Tu tienda',
        'SellerSettledNotification' => 'Liquidación',
        _ => 'Tu pedido',
      };
}
