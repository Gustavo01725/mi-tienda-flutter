import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../services/nav_state.dart';
import '../services/notifications_state.dart';
import '../theme.dart';

/// Estructura común de todas las pantallas, copiada de la web guStore (layouts/app.blade.php):
/// banner superior, barra de idioma y sesión, cabecera fija (logo, buscador, carrito) con las
/// pestañas Inicio / Productos / Pedidos / Billetera, y la barra inferior del móvil.
class GuScaffold extends StatelessWidget {
  final List<Widget> slivers;

  /// Página que se marca en verde en las pestañas y en la barra inferior.
  final AppPage? active;
  final Future<void> Function()? onRefresh;

  const GuScaffold({super.key, required this.slivers, this.active, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: TopBanner()),
      const SliverToBoxAdapter(child: TopBar()),
      SliverPersistentHeader(pinned: true, delegate: _HeaderDelegate(active)),
      ...slivers,
      const SliverToBoxAdapter(child: SizedBox(height: 90)), // espacio para la barra inferior
    ]);
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: onRefresh == null ? scroll : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
      ),
      bottomNavigationBar: GuBottomNav(active: active),
    );
  }
}

/// Banner verde "Welcome to Woot!" (assets/img/top-banner.png); se puede cerrar y no vuelve a salir.
class TopBanner extends StatefulWidget {
  const TopBanner({super.key});
  @override
  State<TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<TopBanner> {
  static bool? _removed; // compartido entre pantallas, igual que la sesión de la web
  static const _key = 'top-banner-removed';

  @override
  void initState() {
    super.initState();
    if (_removed == null) {
      SharedPreferences.getInstance().then((p) {
        _removed = p.getBool(_key) ?? false;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_removed != false) return const SizedBox.shrink();
    return SizedBox(
      height: 50,
      child: Stack(children: [
        Positioned.fill(
          child: Container(
            color: AppColors.primary,
            alignment: Alignment.center,
            child: Image.asset('assets/img/top-banner.png', fit: BoxFit.fitHeight, height: 50),
          ),
        ),
        Positioned(
          right: 4,
          top: 0,
          bottom: 0,
          child: IconButton(
            icon: const Icon(LineAwesomeIcons.times_solid, color: Colors.white, size: 28),
            onPressed: () async {
              setState(() => _removed = true);
              (await SharedPreferences.getInstance()).setBool(_key, true);
            },
          ),
        ),
      ]),
    );
  }
}

/// Barra blanca superior: idioma a la izquierda; "Iniciar Sesión | Registrarse" o "Cerrar Sesión".
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    const soft = TextStyle(fontSize: 13, color: Color(0x991B1B28));
    return Container(
      height: 37,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE6E6EE)))),
      child: Row(children: [
        PopupMenuButton<String>(
          tooltip: 'Idioma',
          position: PopupMenuPosition.under,
          itemBuilder: (_) => [
            PopupMenuItem(value: 'es', child: Row(children: [Image.asset('assets/img/es.png', height: 11), const SizedBox(width: 8), const Text('Español')])),
            PopupMenuItem(
              enabled: false,
              value: 'en',
              child: Row(children: [Image.asset('assets/img/us.png', height: 11), const SizedBox(width: 8), const Text('English (próximamente)')]),
            ),
          ],
          child: Row(children: [
            Image.asset('assets/img/es.png', height: 11),
            const SizedBox(width: 8),
            const Text('Español', style: soft),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0x991B1B28)),
          ]),
        ),
        const Spacer(),
        if (auth.user == null) ...[
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Iniciar Sesión', style: soft)),
          ),
          Container(width: 1, height: 37, color: const Color(0xFFE6E6EE), margin: const EdgeInsets.symmetric(horizontal: 12)),
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Registrarse', style: soft)),
          ),
        ] else
          InkWell(
            onTap: () async {
              await auth.logout();
              if (context.mounted) context.read<NavState>().go(AppPage.home);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(LineAwesomeIcons.sign_out_alt_solid, size: 16, color: Color(0x991B1B28)),
                SizedBox(width: 4),
                Text('Cerrar Sesión', style: soft),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final AppPage? active;
  _HeaderDelegate(this.active);

  static const height = 118.0;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => _Header(active: active);

  @override
  bool shouldRebuild(_HeaderDelegate old) => old.active != active;
}

/// Cabecera fija: logo, lupa (despliega el buscador como en el móvil de la web), carrito con contador,
/// y debajo las pestañas de navegación.
class _Header extends StatefulWidget {
  final AppPage? active;
  const _Header({this.active});
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _search = false;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _q.text.trim();
    setState(() => _search = false);
    context.read<NavState>().openProducts(query: q);
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavState>();
    final count = context.watch<CartState>().cart.count;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, boxShadow: cardShadow),
      child: Column(children: [
        SizedBox(
          height: 70,
          child: _search
              ? Row(children: [
                  IconButton(
                    icon: const Icon(LineAwesomeIcons.arrow_left_solid, size: 26),
                    onPressed: () => setState(() => _search = false),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _q,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Estoy buscando...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(LineAwesomeIcons.search_solid, color: AppColors.primary), onPressed: _submit),
                ])
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => nav.go(AppPage.home),
                      child: Image.asset('assets/img/logo.png', height: 32, filterQuality: FilterQuality.medium),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Buscar',
                      icon: Transform.flip(flipX: true, child: const Icon(LineAwesomeIcons.search_solid, size: 28)),
                      onPressed: () => setState(() => _search = true),
                    ),
                    InkWell(
                      onTap: () => nav.go(AppPage.cart),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Row(children: [
                          const Icon(LineAwesomeIcons.shopping_cart_solid, size: 28, color: Color(0xCC1B1B28)),
                          const SizedBox(width: 4),
                          Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                            child: Text('$count',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
        ),
        Container(
          height: 48,
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final (label, page) in const [
              ('Inicio', AppPage.home),
              ('Productos', AppPage.products),
              ('Pedidos', AppPage.orders),
              ('Billetera', AppPage.wallet),
            ])
              InkWell(
                onTap: () => nav.go(page),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.active == page ? AppColors.primary : const Color(0x991B1B28),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Barra inferior del móvil (.aiz-mobile-bottom-nav): Inicio, Categorías, Carrito (círculo verde
/// elevado), Notificaciones y Cuenta.
class GuBottomNav extends StatelessWidget {
  final AppPage? active;
  const GuBottomNav({super.key, this.active});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavState>();
    final count = context.watch<CartState>().cart.count;
    final unread = context.watch<NotificationsState>().unread;
    final bottom = MediaQuery.of(context).padding.bottom;

    Widget item(String label, Widget icon, AppPage page) {
      final on = active == page;
      return Expanded(
        child: InkWell(
          onTap: () => nav.go(page),
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              IconTheme(data: IconThemeData(size: 22, color: on ? AppColors.primary : const Color(0x991B1B28)), child: icon),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.primary : const Color(0x991B1B28),
                  )),
            ]),
          ),
        ),
      );
    }

    return Container(
      height: 62 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, -1))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        item('Inicio', const Icon(LineAwesomeIcons.home_solid), AppPage.home),
        item('Categorías', const Icon(LineAwesomeIcons.list_ul_solid), AppPage.categories),
        Expanded(
          child: GestureDetector(
            onTap: () => nav.go(AppPage.cart),
            behavior: HitTestBehavior.opaque,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
              Positioned(
                top: -22,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: const Icon(LineAwesomeIcons.shopping_bag_solid, color: Colors.white, size: 28),
                ),
              ),
              Positioned(
                bottom: 8,
                child: Text('Carrito ($count)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: active == AppPage.cart ? AppColors.primary : const Color(0x991B1B28),
                    )),
              ),
            ]),
          ),
        ),
        item(
          'Notificaciones',
          Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.danger,
            label: Text('$unread'),
            child: const Icon(LineAwesomeIcons.bell),
          ),
          AppPage.notifications,
        ),
        item(
          'Cuenta',
          ClipOval(child: Image.asset('assets/img/avatar-place.png', width: 22, height: 22)),
          AppPage.account,
        ),
      ]),
    );
  }
}
