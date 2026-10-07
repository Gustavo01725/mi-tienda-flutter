import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../theme.dart';
import 'common.dart';

void openProduct(BuildContext context, Product p) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id)));

/// Botón redondo blanco sobre la imagen (añadir al carrito). Un producto con talla/color abre la
/// ficha para elegir, igual que el modal rápido de la web.
Future<void> quickAdd(BuildContext context, Product p) async {
  final hasVariants = p.stocks.any((s) => s.variant.isNotEmpty);
  if (hasVariants || context.read<AuthState>().user == null) {
    openProduct(context, p);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<CartState>().add(p.id);
    messenger.showSnackBar(const SnackBar(content: Text('Producto añadido al carrito')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// Tarjeta de las secciones de la portada (.aiz-card-box).
class HomeProductCard extends StatelessWidget {
  final Product product;
  final double width;
  const HomeProductCard(this.product, {super.key, this.width = 176});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: () => openProduct(context, p),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.bg),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              NetImg(p.thumbnail),
              Positioned(
                right: 6,
                top: 6,
                child: _RoundIcon(
                  icon: LineAwesomeIcons.cart_plus_solid,
                  tooltip: 'Añadir al carrito',
                  onTap: p.totalStock > 0 ? () => quickAdd(context, p) : null,
                ),
              ),
              if (p.totalStock == 0)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    color: const Color(0xCC1B1B28),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: const Text('Agotado', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (p.discountPercent > 0)
                  Text(money(p.unitPrice),
                      style: const TextStyle(fontSize: 15, decoration: TextDecoration.lineThrough, color: Color(0x991B1B28))),
                Text(money(p.price), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ]),
              const SizedBox(height: 6),
              Stars(p.rating),
              const SizedBox(height: 6),
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Tarjeta del listado "Todos los productos" (products.blade.php).
class ListingProductCard extends StatelessWidget {
  final Product product;
  const ListingProductCard(this.product, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: () => openProduct(context, p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Container(color: const Color(0xFFEBEBEB), child: NetImg(p.thumbnail)),
              if (p.discountPercent > 0)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Pill('-${p.discountPercent}%', color: AppColors.danger, background: AppColors.dangerSoft),
                ),
              if (p.totalStock == 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Pill('Agotado', color: Colors.white, background: const Color(0xCC1B1B28)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stars(p.rating, size: 11.5, outline: true),
              const SizedBox(height: 6),
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(money(p.price), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
                if (p.discountPercent > 0)
                  Text(money(p.unitPrice),
                      style: const TextStyle(fontSize: 12, color: AppColors.strike, decoration: TextDecoration.lineThrough)),
              ]),
              const SizedBox(height: 4),
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSoft)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _RoundIcon({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 1,
          shadowColor: const Color(0x33000000),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon, size: 16, color: onTap == null ? AppColors.strike : AppColors.text),
            ),
          ),
        ),
      );
}
