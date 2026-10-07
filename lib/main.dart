import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/account_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/products_screen.dart';
import 'screens/wallet_screen.dart';
import 'services/api.dart';
import 'services/auth_state.dart';
import 'services/cart_state.dart';
import 'services/catalog_state.dart';
import 'services/nav_state.dart';
import 'services/notifications_state.dart';
import 'services/orders_state.dart';
import 'services/push_service.dart';
import 'theme.dart';

void main() {
  final api = Api();
  final push = PushService(api);
  runApp(MultiProvider(
    providers: [
      Provider.value(value: api),
      Provider.value(value: push),
      ChangeNotifierProvider(create: (_) => NavState()),
      ChangeNotifierProvider(create: (_) => AuthState(api)..beforeLogout = push.unregister..restore()),
      ChangeNotifierProvider(create: (_) => CatalogState(api)..start()),
      ChangeNotifierProvider(create: (_) => CartState(api)),
      ChangeNotifierProvider(create: (_) => OrdersState(api)),
      ChangeNotifierProvider(create: (_) => NotificationsState(api, pushActive: () => push.active)),
    ],
    child: const MiTiendaApp(),
  ));
}

class MiTiendaApp extends StatelessWidget {
  const MiTiendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'guStore',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: context.read<NavState>().navigatorKey,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final nav = context.watch<NavState>();
    final loggedIn = auth.user != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.read<CartState>().setLoggedIn(loggedIn);
      context.read<OrdersState>().setLoggedIn(loggedIn);
      context.read<NotificationsState>().setLoggedIn(loggedIn);
      if (loggedIn) context.read<PushService>().init();
    });
    if (!auth.ready) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Image.asset('assets/img/logo.png', width: 220)),
      );
    }
    // "Atrás" en una página principal vuelve a Inicio antes de salir de la app.
    return PopScope(
      canPop: nav.page == AppPage.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.go(AppPage.home);
      },
      child: switch (nav.page) {
        AppPage.home => const HomeScreen(),
        AppPage.products => const ProductsScreen(),
        AppPage.orders => const OrdersScreen(),
        AppPage.wallet => const WalletScreen(),
        AppPage.categories => const CategoriesScreen(),
        AppPage.cart => const CartScreen(),
        AppPage.notifications => const NotificationsScreen(),
        AppPage.account => const AccountScreen(),
      },
    );
  }
}
