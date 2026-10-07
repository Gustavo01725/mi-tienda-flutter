import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../services/api.dart';
import '../services/auth_state.dart';
import '../services/nav_state.dart';
import '../services/orders_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

/// "Mis pedidos" (pages/orders.blade.php): cabecera verde, filtros y la lista. Un vendedor ve
/// además la pestaña "Mis ventas" con los pedidos pagados de sus productos.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String? _payment, _delivery;
  final _code = TextEditingController();
  String _codeFilter = '';
  bool _sales = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  static const _deliveryStates = {
    'pending': 'Pendiente',
    'confirmed': 'Confirmado',
    'warehouse': 'En almacén',
    'on_the_way': 'En camino',
    'delivered': 'Entregado',
  };

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final state = context.watch<OrdersState>();
    if (user == null) return const LoginScreen(embedded: true, active: AppPage.orders);

    final all = state.orders;
    final sales = all.where((o) => o.isSale).toList();
    final showTabs = sales.isNotEmpty;
    final source = _sales && showTabs ? sales : all.where((o) => !o.isSale).toList();
    final list = source.where((o) {
      if (_payment != null && (o.paid ? 'paid' : 'unpaid') != _payment) return false;
      if (_delivery != null && o.deliveryStatus != _delivery) return false;
      if (_codeFilter.isNotEmpty && !o.code.toLowerCase().contains(_codeFilter.toLowerCase())) return false;
      return true;
    }).toList();

    Widget dropdown(String label, String? value, Map<String, String> opts, ValueChanged<String?> onChanged) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: value,
              isExpanded: true,
              style: const TextStyle(fontFamily: 'OpenSans', fontSize: 13, color: AppColors.text),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final e in opts.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: onChanged,
            ),
          ]),
        );

    return GuScaffold(
      active: AppPage.orders,
      onRefresh: state.sync,
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(15, 28, 15, 22),
            padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
            decoration: BoxDecoration(gradient: AppColors.ordersGradient, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(LineAwesomeIcons.file_alt, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(_sales && showTabs ? 'Mis ventas' : 'Mis pedidos',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(
                _sales && showTabs
                    ? 'Pedidos pagados de tus productos: confírmalos y envíalos al almacén'
                    : 'Revisa el estado y detalle de todos tus pedidos',
                style: const TextStyle(color: Colors.white, fontSize: 13.6),
              ),
            ]),
          ),
        ),
        if (showTabs)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Mis compras'), icon: Icon(LineAwesomeIcons.shopping_bag_solid)),
                  ButtonSegment(value: true, label: Text('Mis ventas'), icon: Icon(LineAwesomeIcons.store_solid)),
                ],
                selected: {_sales},
                onSelectionChanged: (s) => setState(() => _sales = s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.softPrimary,
                  selectedForegroundColor: AppColors.primary,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: GuCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                dropdown('Estado de pago', _payment, const {'paid': 'Pagado', 'unpaid': 'Sin pagar'},
                    (v) => setState(() => _payment = v)),
                const SizedBox(width: 12),
                dropdown('Estado de entrega', _delivery, _deliveryStates, (v) => setState(() => _delivery = v)),
              ]),
              const SizedBox(height: 16),
              const Text('Código de pedido', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    decoration: const InputDecoration(hintText: 'Escribe el código...'),
                    onSubmitted: (v) => setState(() => _codeFilter = v.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  icon: Transform.flip(flipX: true, child: const Icon(LineAwesomeIcons.search_solid, size: 16)),
                  label: const Text('Filtrar'),
                  onPressed: () => setState(() => _codeFilter = _code.text.trim()),
                ),
              ]),
              const SizedBox(height: 12),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.textSoft, backgroundColor: const Color(0xFFF0F1F4)),
                icon: const Icon(LineAwesomeIcons.times_solid, size: 14),
                label: const Text('Limpiar', style: TextStyle(fontWeight: FontWeight.w400)),
                onPressed: () => setState(() {
                  _payment = _delivery = null;
                  _code.clear();
                  _codeFilter = '';
                }),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 15, 12),
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Pedidos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              TextSpan(text: '  (${list.length} en total)', style: const TextStyle(fontSize: 13, color: AppColors.muted3)),
            ])),
          ),
        ),
        if (list.isEmpty)
          const SliverToBoxAdapter(
            child: GuCard(child: EmptyState(icon: LineAwesomeIcons.file_alt, text: 'No hay pedidos con estos filtros.')),
          )
        else
          SliverList.builder(itemCount: list.length, itemBuilder: (_, i) => _OrderCard(list[i])),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard(this.order);

  @override
  Widget build(BuildContext context) {
    final o = order;
    final date = o.createdAt?.toLocal();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))),
      child: GuCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(o.code, style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w600, fontSize: 13.5))),
            Text(money(o.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          if (date != null)
            Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted2)),
          const SizedBox(height: 8),
          Text('${o.items.length} ${o.items.length == 1 ? 'producto' : 'productos'}: ${o.items.map((i) => i.name).join(', ')}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSoft)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            Pill.status(o.paymentLabel, ok: o.paid),
            Pill.status(o.deliveryLabel, ok: o.deliveryStatus == 'delivered', warn: o.deliveryStatus != 'delivered'),
          ]),
        ]),
      ),
    );
  }
}

final _inFlight = <int>{};

/// Acciones del vendedor sobre un pedido (confirmar y enviar al almacén). Un doble toque no
/// manda la acción dos veces.
Future<void> sellerAction(BuildContext context, int orderId, String action) async {
  if (!_inFlight.add(orderId)) return;
  try {
    final r = await context.read<Api>().post('/seller/orders/$orderId/$action');
    if (context.mounted) context.read<OrdersState>().apply(Order.fromJson(r));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  } finally {
    _inFlight.remove(orderId);
  }
}
