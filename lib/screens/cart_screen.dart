import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cart_state.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CartState>();
    final cart = state.cart;
    return Scaffold(
      appBar: AppBar(title: const Text('Carrito')),
      body: cart.items.isEmpty
          ? const Center(child: Text('Tu carrito está vacío'))
          : Column(children: [
              Expanded(
                child: ListView(children: [
                  for (final i in cart.items)
                    ListTile(
                      leading: SizedBox(width: 56, child: CachedNetworkImage(imageUrl: i.thumbnail, fit: BoxFit.cover)),
                      title: Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text([if (i.variantLabel.isNotEmpty) i.variantLabel, '\$${i.price.toStringAsFixed(2)}'].join(' · ')),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: i.quantity > 1 ? () => _run(context, () => state.setQuantity(i.id, i.quantity - 1)) : null,
                        ),
                        Text('${i.quantity}'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: i.availableStock != null && i.quantity >= i.availableStock!
                              ? null
                              : () => _run(context, () => state.setQuantity(i.id, i.quantity + 1)),
                        ),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _run(context, () => state.remove(i.id))),
                      ]),
                    ),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _row('Subtotal', cart.subtotal),
                    _row('Envío', cart.shipping),
                    if (cart.tax > 0) _row('Impuestos', cart.tax),
                    _row('Total', cart.total, bold: true),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                        child: const Text('Continuar al pago'),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }

  Widget _row(String label, double v, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : null);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: style),
      Text('\$${v.toStringAsFixed(2)}', style: style),
    ]);
  }
}
