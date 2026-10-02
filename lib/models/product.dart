class Stock {
  final int id;
  final String? size, color, sku;
  final String variant;
  final double price;
  final int qty;
  Stock.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        size = j['size'],
        color = j['color'],
        sku = j['sku'],
        variant = j['variant'] ?? '',
        price = (j['price'] as num).toDouble(),
        qty = j['qty'];
}

class Product {
  final int id;
  final String name, thumbnail;
  final String? category, brand, unit, shortDescription, description;
  final double unitPrice, price;
  final int discount, totalStock, lowStockQty;
  final bool published, featured;
  final List<String> photos;
  final List<Stock> stocks;
  final DateTime? updatedAt;

  Product.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        thumbnail = j['thumbnail'] ?? '',
        category = j['category'],
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
        featured = j['featured'] ?? false,
        photos = List<String>.from(j['photos'] ?? const []),
        stocks = (j['stocks'] as List? ?? const []).map((s) => Stock.fromJson(s)).toList(),
        updatedAt = j['updated_at'] == null ? null : DateTime.tryParse(j['updated_at']);

  bool get lowStock => totalStock <= lowStockQty;
}
