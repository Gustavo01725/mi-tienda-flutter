import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/cart.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

/// "Carrito de compras" (cart/index.blade.php): una tarjeta por artículo y el resumen del pedido.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CartState>();
    final cart = state.cart;
    final loggedIn = context.watch<AuthState>().user != null;
    final nav = context.read<NavState>();

    return GuScaffold(
      active: AppPage.cart,
      onRefresh: loggedIn ? state.refresh : null,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 22, 15, 16),
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Carrito de compras', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              TextSpan(
                text: '  (${cart.count} ${cart.count == 1 ? 'artículo' : 'artículos'})',
                style: const TextStyle(fontSize: 13, color: AppColors.muted3),
              ),
            ])),
          ),
        ),
        if (!loggedIn)
          SliverToBoxAdapter(
            child: GuCard(
              child: EmptyState(
                icon: LineAwesomeIcons.shopping_cart_solid,
                text: 'Inicia sesión para ver tu carrito',
                action: FilledButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Iniciar sesión'),
                ),
              ),
            ),
          )
        else if (cart.items.isEmpty)
          SliverToBoxAdapter(
            child: GuCard(
              child: EmptyState(
                icon: LineAwesomeIcons.shopping_cart_solid,
                text: 'Tu carrito está vacío',
                action: FilledButton(onPressed: () => nav.go(AppPage.products), child: const Text('Seguir comprando')),
              ),
            ),
          )
        else ...[
          SliverList.builder(
            itemCount: cart.items.length,
            itemBuilder: (_, i) => _CartItemCard(
              cart.items[i],
              onQty: (q) => _run(context, () => state.setQuantity(cart.items[i].id, q)),
              onRemove: () => _run(context, () => state.remove(cart.items[i].id)),
            ),
          ),
          SliverToBoxAdapter(
            child: GuCard(
              margin: const EdgeInsets.fromLTRB(15, 20, 15, 16),
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Resumen del pedido', style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                SummaryRow('Subtotal', money(cart.subtotal), bold: true),
                SummaryRow('Envío', money(cart.shipping), bold: true),
                SummaryRow('Impuesto', money(cart.tax), bold: true),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                SummaryRow('Total', money(cart.total), big: true, green: true),
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(LineAwesomeIcons.lock_solid, size: 18),
                  label: const Text('Ir a pagar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => nav.go(AppPage.products), child: const Text('← Seguir comprando')),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;
  const _CartItemCard(this.item, {required this.onQty, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final i = item;
    final short = i.availableStock != null && i.quantity > i.availableStock!;
    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted2)),
            const Spacer(),
            value,
          ]),
        );
    return GuCard(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 14),
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 56, height: 56, child: NetImg(i.thumbnail))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              VariantChips(i.parts, fallback: i.variantLabel),
              if (short)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(i.availableStock == 0 ? 'Agotado' : 'Solo quedan ${i.availableStock}',
                      style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(LineAwesomeIcons.times_circle, color: AppColors.muted3, size: 24),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        row('Precio', Text(money(i.price), style: const TextStyle(fontSize: 14))),
        row(
          'Cantidad',
          QtyStepper(
            value: i.quantity,
            max: i.availableStock,
            onChanged: onQty,
          ),
        ),
        row('Envío', Text(money(i.shippingCost), style: const TextStyle(fontSize: 14))),
        row('Subtotal', Text(money(i.subtotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary))),
      ]),
    );
  }
}
