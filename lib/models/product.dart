import 'package:flutter/painting.dart';

class Stock {
  final int id;
  final String? size, color, sku, colorLabel, colorHex;
  final String variant;
  final double price;

  /// Precio que cobra el carrito por esta variante (con el descuento del producto aplicado).
  final double finalPrice;
  final int qty;
  Stock.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        size = j['size'],
        color = j['color'],
        colorLabel = j['color_label'],
        colorHex = j['color_hex'],
        sku = j['sku'],
        variant = j['variant'] ?? '',
        price = (j['price'] as num).toDouble(),
        finalPrice = ((j['final_price'] ?? j['price']) as num).toDouble(),
        qty = j['qty'];

  Color? get swatch => parseHex(colorHex);
}

/// '#1a1a1a' → Color. null si no es un hex válido.
Color? parseHex(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 3 ? h.split('').map((c) => '$c$c').join() : h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

class Product {
  final int id;
  final String name, thumbnail;
  final String? category, brand, unit, shortDescription, description, sizeLabel;
  final int? categoryId;
  final int numOfSale, reviewsCount;
  final double rating;
  final DateTime? createdAt;
  final double unitPrice, price;
  final int discount, totalStock, lowStockQty;
  final bool published, approved, featured;
  final List<String> photos;
  final List<String>? _sizes, _colorKeys;
  final List<Stock> stocks;
  final DateTime? updatedAt;

  Product.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        thumbnail = j['thumbnail'] ?? '',
        category = j['category'],
        categoryId = j['category_id'],
        sizeLabel = j['size_label'],
        numOfSale = j['num_of_sale'] ?? 0,
        reviewsCount = j['reviews_count'] ?? 0,
        rating = ((j['rating'] ?? 0) as num).toDouble(),
        createdAt = DateTime.tryParse(j['created_at'] ?? ''),
        brand = j['brand'],
        unit = j['unit'],
        shortDescription = j['short_description'],
        description = j['description'],
        unitPrice = (j['unit_price'] as num).toDouble(),
        price = (j['price'] as num).toDouble(),
        discount = j['discount'] ?? 0,
        totalStock = j['total_stock'] ?? 0,
        lowStockQty = j['low_stock_qty'] ?? 5,
        published = j['published'] ?? true,
        approved = j['approved'] ?? true,
        featured = j['featured'] ?? false,
        photos = List<String>.from(j['photos'] ?? const []),
        _sizes = j['sizes'] is List ? List<String>.from(j['sizes']) : null,
        _colorKeys = j['colors'] is List ? List<String>.from(j['colors']) : null,
        stocks = (j['stocks'] as List? ?? const []).map((s) => Stock.fromJson(s)).toList(),
        updatedAt = j['updated_at'] == null ? null : DateTime.tryParse(j['updated_at']);

  bool get lowStock => totalStock <= lowStockQty;

  /// Porcentaje de descuento a mostrar ("-10%"), calculado como en la web.
  int get discountPercent => unitPrice > 0 && price < unitPrice ? ((1 - price / unitPrice) * 100).round() : 0;

  /// Tallas en el orden de la web (config/variants.php); si la API no lo manda, el de las filas.
  List<String> get sizes => _sizes ?? {for (final s in stocks) if (s.size != null && s.size!.isNotEmpty) s.size!}.toList();

  /// Una fila de stock por color (para su nombre y hex), en el orden de la paleta de la web.
  List<Stock> get colors {
    final seen = <String>{};
    final byColor = [for (final s in stocks) if (s.color != null && s.color!.isNotEmpty && seen.add(s.color!)) s];
    final order = _colorKeys;
    if (order == null) return byColor;
    return [for (final c in order) ...byColor.where((s) => s.color == c)];
  }
}
