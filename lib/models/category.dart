class ShopCategory {
  final int id;
  final String name;
  final int? parentId;
  final String? icon, banner;
  final bool featured;
  final int productsCount;

  ShopCategory.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        parentId = j['parent_id'],
        icon = j['icon'],
        banner = j['banner'],
        featured = j['featured'] ?? false,
        productsCount = j['products_count'] ?? 0;

  String? get image => icon ?? banner;
}
