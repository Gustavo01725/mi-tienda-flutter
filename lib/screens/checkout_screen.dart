import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../services/orders_state.dart';

/// Datos de envío + pago con Stripe PaymentSheet. El pedido se crea en el servidor
/// al pulsar "Pagar" (igual que la web), y se confirma con el webhook de Stripe.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  bool _busy = false;
  String? _error;

  static const _fields = {
    'full_name': 'Nombre completo',
    'phone': 'Teléfono',
    'email': 'Correo',
    'address': 'Dirección',
    'city': 'Ciudad',
    'state': 'Provincia / estado',
    'country': 'País',
    'postal_code': 'Código postal',
  };
  static const _optional = {'state', 'country', 'postal_code'};

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthState>().user;
    _c = {for (final k in _fields.keys) k: TextEditingController()};
    _c['full_name']!.text = u?.name ?? '';
    _c['email']!.text = u?.email ?? '';
    _c['phone']!.text = u?.phone ?? '';
  }

  Future<void> _pay() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Api>();
    final cart = context.read<CartState>();
    final orders = context.read<OrdersState>();
    final nav = Navigator.of(context);
    try {
      final r = await api.post('/checkout/intent', {
        for (final e in _c.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      });
      Stripe.publishableKey = r['publishable_key'];
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: r['client_secret'],
          merchantDisplayName: 'Mi Tienda',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // Pago aprobado: pedimos al servidor que lo verifique con Stripe (el webhook puede tardar).
      await api.post('/orders/${r['order_id']}/confirm-payment');
      await cart.refresh();
      await orders.sync();
      if (!mounted) return;
      nav.popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(nav.context).showSnackBar(SnackBar(content: Text('¡Pedido ${r['code']} pagado!')));
    } on StripeException catch (e) {
      // Cancelar la hoja de pago no es un error.
      if (e.error.code != FailureCode.Canceled) setState(() => _error = e.error.localizedMessage ?? 'No se pudo completar el pago');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = context.watch<CartState>().cart.total;
    return Scaffold(
      appBar: AppBar(title: const Text('Pago')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Datos de envío', style: Theme.of(context).textTheme.titleMedium),
          for (final e in _fields.entries)
            TextFormField(
              controller: _c[e.key],
              decoration: InputDecoration(labelText: e.value),
              validator: (v) => !_optional.contains(e.key) && (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _pay, child: Text('Pagar \$${total.toStringAsFixed(2)}')),
        ]),
      ),
    );
  }
}
