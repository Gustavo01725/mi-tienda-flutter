import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductTile({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return InkWell(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: p.thumbnail,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Text('\$${p.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (p.discount > 0) ...[
                  const SizedBox(width: 6),
                  Text('\$${p.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 12, color: Colors.grey)),
                ],
              ]),
              Text(p.totalStock > 0 ? 'Stock: ${p.totalStock}' : 'Agotado',
                  style: TextStyle(fontSize: 12, color: p.totalStock > 0 ? Colors.green : Colors.red)),
            ]),
          ),
        ]),
      ),
    );
  }
}
