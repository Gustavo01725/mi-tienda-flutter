import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/catalog_state.dart';

/// Lee el producto del catálogo en cada rebuild, así el stock cambia en vivo
/// cuando alguien lo modifica en la web.
class ProductDetailScreen extends StatelessWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CatalogState>().products.where((e) => e.id == productId).firstOrNull;
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Este producto ya no está disponible')));
    }
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
            Text('\$${p.price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text('Disponibilidad', style: Theme.of(context).textTheme.titleMedium),
            for (final s in p.stocks)
              ListTile(
                dense: true,
                title: Text(s.variant.isEmpty ? 'Único' : s.variant),
                trailing: Text(s.qty > 0 ? '${s.qty} uds · \$${s.price.toStringAsFixed(2)}' : 'Agotado'),
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
