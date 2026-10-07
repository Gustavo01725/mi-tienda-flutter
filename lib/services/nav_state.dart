import 'package:flutter/material.dart';

/// Páginas principales: las pestañas de arriba (Inicio, Productos, Pedidos, Billetera) y la barra
/// inferior (Inicio, Categorías, Carrito, Notificaciones, Cuenta), igual que en la web.
enum AppPage { home, products, orders, wallet, categories, cart, notifications, account }

enum ProductSort { newest, priceAsc, priceDesc, bestSelling }

/// Página actual y filtros del listado de productos. Cualquier pantalla (incluso una abierta encima,
/// como el detalle de un producto) puede saltar a una página principal: se vuelve a la raíz.
class NavState extends ChangeNotifier {
  AppPage page = AppPage.home;

  String query = '';
  int? categoryId;
  ProductSort sort = ProductSort.newest;

  /// Clave del Navigator de la app, para volver a la raíz desde cualquier sitio.
  final navigatorKey = GlobalKey<NavigatorState>();

  void go(AppPage p) {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    if (page == p) return;
    page = p;
    notifyListeners();
  }

  /// Abre "Productos" con una búsqueda o una categoría (buscador de la cabecera, categorías).
  void openProducts({String? query, int? categoryId}) {
    this.query = query ?? '';
    this.categoryId = categoryId;
    page = AppPage.products;
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    notifyListeners();
  }

  void setSort(ProductSort s) {
    sort = s;
    notifyListeners();
  }

  void clearFilters() {
    query = '';
    categoryId = null;
    notifyListeners();
  }
}
