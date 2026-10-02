import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/api.dart';
import 'services/auth_state.dart';
import 'services/catalog_state.dart';

void main() {
  final api = Api();
  runApp(MultiProvider(
    providers: [
      Provider.value(value: api),
      ChangeNotifierProvider(create: (_) => AuthState(api)..restore()),
      ChangeNotifierProvider(create: (_) => CatalogState(api)..start()),
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
    if (!auth.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return const HomeScreen();
  }
}
