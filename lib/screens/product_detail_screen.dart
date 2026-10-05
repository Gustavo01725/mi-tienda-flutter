import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../services/catalog_state.dart';
import 'login_screen.dart';

/// Lee el producto del catálogo en cada rebuild, así el stock cambia en vivo
/// cuando alguien lo modifica en la web.
class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _variant;
  bool _busy = false;

  Future<void> _add(bool hasVariants) async {
    final auth = context.read<AuthState>();
    if (auth.user == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    if (hasVariants && _variant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elige talla y color')));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<CartState>().add(widget.productId, variation: _variant);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Añadido al carrito')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CatalogState>().byId(widget.productId);
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Este producto ya no está disponible')));
    }
    final hasVariants = p.stocks.any((s) => s.variant.isNotEmpty);
    // Si la variante elegida se agotó en la web mientras se miraba, se descarta.
    if (_variant != null && !p.stocks.any((s) => s.variant == _variant && s.qty > 0)) _variant = null;
    // El precio que se cobra es el de la variante (con descuento), no siempre el precio base.
    final selected = p.stocks.where((s) => s.variant == (_variant ?? '')).firstOrNull ??
        (hasVariants ? null : p.stocks.firstOrNull);
    final shownPrice = selected?.finalPrice ?? p.price;

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(children: [
        SizedBox(
          height: 280,
          child: PageView(children: [
            for (final url in [p.thumbnail, ...p.photos]) CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: Theme.of(context).textTheme.titleLarge),
            if (p.category != null) Text(p.category!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('\$${shownPrice.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(hasVariants ? 'Elige una opción' : 'Disponibilidad', style: Theme.of(context).textTheme.titleMedium),
            if (hasVariants)
              Wrap(spacing: 8, children: [
                for (final s in p.stocks)
                  ChoiceChip(
                    label: Text('${s.variant} (${s.qty})'),
                    selected: _variant == s.variant,
                    onSelected: s.qty > 0 ? (_) => setState(() => _variant = s.variant) : null,
                  ),
              ])
            else
              Text(p.totalStock > 0 ? '${p.totalStock} disponibles' : 'Agotado'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                onPressed: _busy || p.totalStock == 0 ? null : () => _add(hasVariants),
                label: Text(p.totalStock == 0 ? 'Agotado' : 'Añadir al carrito'),
              ),
            ),
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(p.description!.replaceAll(RegExp(r'<[^>]*>'), '')),
            ],
          ]),
        ),
      ]),
    );
  }
}
