import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/api.dart';
import 'services/auth_state.dart';
import 'services/cart_state.dart';
import 'services/catalog_state.dart';
import 'services/notifications_state.dart';
import 'services/orders_state.dart';
import 'services/push_service.dart';

void main() {
  final api = Api();
  final push = PushService(api);
  runApp(MultiProvider(
    providers: [
      Provider.value(value: api),
      Provider.value(value: push),
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
      title: 'Mi Tienda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final loggedIn = auth.user != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.read<CartState>().setLoggedIn(loggedIn);
      context.read<OrdersState>().setLoggedIn(loggedIn);
      context.read<NotificationsState>().setLoggedIn(loggedIn);
      if (loggedIn) context.read<PushService>().init();
    });
    if (!auth.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return const HomeScreen();
  }
}
