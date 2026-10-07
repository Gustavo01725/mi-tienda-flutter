import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../services/nav_state.dart';
import '../services/orders_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'orders_screen.dart';

/// Detalle de un pedido (pages/order-detail.blade.php).
class OrderDetailScreen extends StatelessWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static const _steps = ['pending', 'confirmed', 'warehouse', 'on_the_way', 'delivered'];
  static const _stepLabels = ['Pendiente', 'Confirmado', 'Almacén', 'En camino', 'Entregado'];

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavState>();
    final o = context.watch<OrdersState>().byId(orderId);
    if (o == null) {
      return const GuScaffold(
        active: AppPage.orders,
        slivers: [SliverToBoxAdapter(child: EmptyState(icon: LineAwesomeIcons.file_alt, text: 'Pedido no encontrado.'))],
      );
    }
    // El rol viene del servidor: así funciona igual al abrir el pedido desde un aviso.
    final sellerView = o.isSale;
    final ship = o.shipping;
    final step = _steps.indexOf(o.deliveryStatus);

    return GuScaffold(
      active: AppPage.orders,
      slivers: [
        SliverToBoxAdapter(
          child: Breadcrumb([('Inicio', () => nav.go(AppPage.home)), ('Pedidos', () => nav.go(AppPage.orders)), (o.code, null)]),
        ),
        SliverToBoxAdapter(
          child: GuCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pedido ${o.code}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                Pill.status(o.paymentLabel, ok: o.paid),
                Pill.status(o.deliveryLabel, ok: o.deliveryStatus == 'delivered', warn: true),
              ]),
              const SizedBox(height: 20),
              // Línea de progreso de la entrega.
              Row(children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  Column(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: i <= step ? AppColors.primary : AppColors.border,
                      child: Icon(i < step || (i == step && i == _steps.length - 1) ? Icons.check : Icons.circle,
                          size: i <= step ? 14 : 6, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 54,
                      child: Text(_stepLabels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: i <= step ? AppColors.primary : AppColors.muted3, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  if (i < _steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 18),
                        color: i < step ? AppColors.primary : AppColors.border,
                      ),
                    ),
                ],
              ]),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: GuCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(sellerView ? 'Tus productos en este pedido' : 'Productos',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Divider(),
              for (final i in o.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 52, height: 52, child: NetImg(i.thumbnail))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        VariantChips(i.parts, fallback: i.variantLabel),
                        const SizedBox(height: 4),
                        Text('${money(i.price)} × ${i.quantity}', style: const TextStyle(fontSize: 12, color: AppColors.muted2)),
                      ]),
                    ),
                    Text(money(i.price * i.quantity), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              const Divider(),
              const SizedBox(height: 6),
              SummaryRow('Subtotal', money(o.subtotal)),
              SummaryRow('Envío', money(o.shippingTotal)),
              if (o.taxAmount > 0) SummaryRow('Impuesto', money(o.taxAmount)),
              SummaryRow(sellerView ? 'Tu parte del pedido' : 'Total', money(o.total), big: true, green: true),
            ]),
          ),
        ),
        if (ship.isNotEmpty)
          SliverToBoxAdapter(
            child: GuCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(LineAwesomeIcons.truck_solid, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Datos de envío', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 12),
                for (final (k, label) in const [
                  ('full_name', 'Nombre'),
                  ('phone', 'Teléfono'),
                  ('email', 'Correo'),
                  ('address', 'Dirección'),
                  ('city', 'Ciudad'),
                  ('state', 'Provincia'),
                  ('country', 'País'),
                ])
                  if ('${ship[k] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.muted2))),
                        Expanded(child: Text('${ship[k]}')),
                      ]),
                    ),
              ]),
            ),
          ),
        if (sellerView && (o.deliveryStatus == 'pending' || o.deliveryStatus == 'confirmed'))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: FilledButton.icon(
                icon: Icon(o.deliveryStatus == 'pending' ? LineAwesomeIcons.check_solid : LineAwesomeIcons.warehouse_solid),
                label: Text(o.deliveryStatus == 'pending' ? 'Confirmar pedido' : 'Enviar al almacén'),
                onPressed: () => sellerAction(context, o.id, o.deliveryStatus == 'pending' ? 'confirm' : 'send-to-warehouse'),
              ),
            ),
          ),
      ],
    );
  }
}
