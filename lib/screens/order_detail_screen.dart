import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/orders_state.dart';
import 'orders_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final o = context.watch<OrdersState>().byId(orderId);
    if (o == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Pedido no encontrado')));
    // El rol viene del servidor: así funciona igual al abrir el pedido desde un aviso.
    final sellerView = o.isSale;
    final ship = o.shipping;
    return Scaffold(
      appBar: AppBar(title: Text(o.code)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${o.paid ? 'Pagado' : 'Sin pagar'} · ${o.deliveryLabel}', style: Theme.of(context).textTheme.titleMedium),
        const Divider(),
        for (final i in o.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i.name),
            subtitle: Text([if (i.variantLabel.isNotEmpty) i.variantLabel, 'x${i.quantity}'].join(' · ')),
            trailing: Text('\$${(i.price * i.quantity).toStringAsFixed(2)}'),
          ),
        const Divider(),
        Text('${sellerView ? 'Tu parte del pedido' : 'Total'}: \$${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        if (ship.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Envío a', style: Theme.of(context).textTheme.titleSmall),
          Text([ship['full_name'], ship['address'], ship['city'], ship['phone']].where((e) => e != null && '$e'.isNotEmpty).join('\n')),
        ],
        if (sellerView && o.deliveryStatus == 'pending')
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FilledButton(onPressed: () => sellerAction(context, o.id, 'confirm'), child: const Text('Confirmar pedido')),
          ),
        if (sellerView && o.deliveryStatus == 'confirmed')
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FilledButton(onPressed: () => sellerAction(context, o.id, 'send-to-warehouse'), child: const Text('Enviar al almacén')),
          ),
      ]),
    );
  }
}
