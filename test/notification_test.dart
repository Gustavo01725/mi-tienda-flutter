import 'package:flutter_test/flutter_test.dart';
import 'package:mi_tienda/models/app_notification.dart';

void main() {
  test('AppNotification asigna título por tipo y lee pedido', () {
    final n = AppNotification.fromJson({
      'id': 'a', 'message': 'Nuevo pedido #1', 'type': 'SellerNewOrderNotification',
      'order_id': 5, 'read': false, 'created_at': '2026-10-02T10:00:00+00:00',
    });
    expect(n.title, 'Nueva venta');
    expect(n.orderId, 5);
    expect(n.read, isFalse);
  });
}
