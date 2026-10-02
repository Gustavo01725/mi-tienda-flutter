import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../services/api.dart';
import '../services/auth_state.dart';
import '../services/orders_state.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final all = context.watch<OrdersState>().orders;
    final mine = all.where((o) => o.userId == user?.id).toList();
    final sales = all.where((o) => o.userId != user?.id && o.paid).toList();
    final isSeller = user != null && (user.isSeller || user.isAdmin) && sales.isNotEmpty;

    Widget list(List<Order> orders) => RefreshIndicator(
          onRefresh: context.read<OrdersState>().sync,
          child: orders.isEmpty
              ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Sin pedidos'))])
              : ListView(children: [
                  for (final o in orders)
                    ListTile(
                      title: Text(o.code),
                      subtitle: Text('${o.paid ? 'Pagado' : 'Sin pagar'} · ${o.deliveryLabel}'),
                      trailing: Text('\$${o.total.toStringAsFixed(2)}'),
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id, sellerView: o.userId != user?.id))),
                    ),
                ]),
        );

    if (!isSeller) return Scaffold(appBar: AppBar(title: const Text('Mis pedidos')), body: list(mine));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pedidos'), bottom: const TabBar(tabs: [Tab(text: 'Mis compras'), Tab(text: 'Mis ventas')])),
        body: TabBarView(children: [list(mine), list(sales)]),
      ),
    );
  }
}

/// Acciones del vendedor sobre un pedido (confirmar y enviar al almacén).
Future<void> sellerAction(BuildContext context, int orderId, String action) async {
  try {
    final r = await context.read<Api>().post('/seller/orders/$orderId/$action');
    if (context.mounted) context.read<OrdersState>().apply(Order.fromJson(r));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}
