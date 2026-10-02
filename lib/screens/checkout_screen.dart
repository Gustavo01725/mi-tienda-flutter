import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../services/kushki_client.dart';
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
  String _gateway = 'stripe';
  Map<String, dynamic> _kushki = {};
  String _docType = 'CC';
  final _card = {for (final k in ['name', 'number', 'month', 'year', 'cvv', 'doc']) k: TextEditingController()};

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
    _loadGateway();
  }

  /// La web decide la pasarela por país (Ecuador → Kushki, resto → Stripe); la app pregunta a la API.
  Future<void> _loadGateway() async {
    try {
      final r = await context.read<Api>().get('/checkout/gateway');
      if (mounted) {
        setState(() {
          _gateway = r['gateway'];
          _kushki = Map<String, dynamic>.from(r['kushki'] ?? {});
        });
      }
    } catch (_) {
      // sin respuesta se queda en Stripe
    }
  }

  Future<void> _pay() async {
    if (!_form.currentState!.validate()) return;
    return _gateway == 'kushki' ? _payKushki() : _payStripe();
  }

  Map<String, String> get _shipping => {
        for (final e in _c.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      };

  Future<void> _payKushki() async {
    final publicId = _kushki['public_id'] as String?;
    if (publicId == null || publicId.isEmpty) {
      setState(() => _error = 'Kushki no está configurado en el servidor');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Api>();
    final cart = context.read<CartState>();
    final orders = context.read<OrdersState>();
    final nav = Navigator.of(context);
    try {
      final total = cart.cart.total;
      final token = await KushkiClient(publicId: publicId, production: _kushki['env'] == 'production').tokenize(
        name: _card['name']!.text.trim(),
        number: _card['number']!.text,
        expiryMonth: _card['month']!.text.trim(),
        expiryYear: _card['year']!.text.trim(),
        cvv: _card['cvv']!.text.trim(),
        totalAmount: total,
      );
      final parts = _c['full_name']!.text.trim().split(RegExp(r'\s+'));
      final r = await api.post('/checkout/kushki', {
        ..._shipping,
        'token': token,
        'document_type': _docType,
        'document_number': _card['doc']!.text.trim(),
        'first_name': parts.first,
        'last_name': parts.length > 1 ? parts.sublist(1).join(' ') : parts.first,
      });
      await cart.refresh();
      await orders.sync();
      if (!mounted) return;
      nav.popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(nav.context).showSnackBar(SnackBar(content: Text('¡Pedido ${r['code']} pagado!')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payStripe() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Api>();
    final cart = context.read<CartState>();
    final orders = context.read<OrdersState>();
    final nav = Navigator.of(context);
    try {
      final r = await api.post('/checkout/intent', _shipping);
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

  String? _req(String? v) => v == null || v.trim().isEmpty ? 'Requerido' : null;

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
          if (_gateway == 'kushki') ...[
            const SizedBox(height: 16),
            Text('Tarjeta (Kushki)', style: Theme.of(context).textTheme.titleMedium),
            TextFormField(controller: _card['name'], decoration: const InputDecoration(labelText: 'Nombre en la tarjeta'), validator: _req),
            TextFormField(
                controller: _card['number'],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de tarjeta'),
                validator: _req),
            Row(children: [
              Expanded(child: TextFormField(controller: _card['month'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mes (MM)'), validator: _req)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _card['year'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Año (AA)'), validator: _req)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _card['cvv'], keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'CVV'), validator: _req)),
            ]),
            Row(children: [
              DropdownButton<String>(
                value: _docType,
                items: const [
                  DropdownMenuItem(value: 'CC', child: Text('Cédula')),
                  DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                  DropdownMenuItem(value: 'PP', child: Text('Pasaporte')),
                ],
                onChanged: (v) => setState(() => _docType = v!),
              ),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _card['doc'], decoration: const InputDecoration(labelText: 'N.º de documento'), validator: _req)),
            ]),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _pay, child: Text('Pagar \$${total.toStringAsFixed(2)}')),
        ]),
      ),
    );
  }
}
