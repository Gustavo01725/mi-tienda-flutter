import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../services/catalog_state.dart';
import '../services/cart_state.dart';
import 'cart_screen.dart';
import 'inventory_screen.dart';
import '../services/notifications_state.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'product_tile.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final items = catalog.products.where((p) => p.name.toLowerCase().contains(_q.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Tienda'),
        actions: [
          if (user != null && (user.isSeller || user.isAdmin))
            IconButton(
              tooltip: 'Inventario',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
            ),
          if (user != null && user.isAdmin)
            IconButton(
              tooltip: 'Usuarios',
              icon: const Icon(Icons.people_outline),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())),
            ),
          if (user != null) ...[
            IconButton(
              tooltip: 'Avisos',
              icon: Badge(
                isLabelVisible: context.watch<NotificationsState>().unread > 0,
                label: Text('${context.watch<NotificationsState>().unread}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            IconButton(
              tooltip: 'Pedidos',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
            ),
            IconButton(
              tooltip: 'Carrito',
              icon: Badge(
                isLabelVisible: context.watch<CartState>().cart.count > 0,
                label: Text('${context.watch<CartState>().cart.count}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            ),
          ],
          if (user == null)
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Entrar'),
            )
          else
            PopupMenuButton<String>(
              onSelected: (_) => auth.logout(),
              itemBuilder: (_) => [
                PopupMenuItem(enabled: false, child: Text(user.email)),
                const PopupMenuItem(value: 'out', child: Text('Cerrar sesión')),
              ],
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar productos', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        if (catalog.error != null)
          MaterialBanner(content: Text(catalog.error!), actions: [TextButton(onPressed: catalog.sync, child: const Text('Reintentar'))]),
        Expanded(
          child: RefreshIndicator(
            onRefresh: catalog.sync,
            child: items.isEmpty
                ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Sin productos'))])
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220, childAspectRatio: 0.68, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) => ProductTile(
                      product: items[i],
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: items[i].id))),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}
