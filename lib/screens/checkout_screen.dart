import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../services/kushki_client.dart';
import '../services/orders_state.dart';

/// Datos de envío + pago. La pasarela la decide la API como en la web (Ecuador → Kushki, resto →
/// Stripe). El pedido se crea en el servidor al pulsar "Pagar" y lo marca pagado el cobro o el webhook.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  final _card = {for (final k in ['name', 'number', 'month', 'year', 'cvv', 'doc']) k: TextEditingController()};
  bool _busy = false;
  String? _error;

  /// null mientras se consulta: no se puede pagar sin saber por qué pasarela.
  String? _gateway;
  bool _gatewayFailed = false;
  Map<String, dynamic> _kushki = {};
  String _docType = 'CC';

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

  @override
  void dispose() {
    for (final c in [..._c.values, ..._card.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadGateway() async {
    setState(() => _gatewayFailed = false);
    try {
      final r = await context.read<Api>().get('/checkout/gateway');
      if (!mounted) return;
      setState(() {
        _gateway = r['gateway'] == 'kushki' ? 'kushki' : 'stripe';
        _kushki = Map<String, dynamic>.from(r['kushki'] ?? {});
        // Dirección guardada en la web (o de la compra anterior): solo rellena campos vacíos.
        final saved = r['shipping'];
        if (saved is Map) {
          for (final e in _c.entries) {
            final v = saved[e.key];
            if (e.value.text.trim().isEmpty && v is String && v.trim().isNotEmpty) e.value.text = v;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _gatewayFailed = true);
    }
  }

  Future<void> _pay() async {
    if (_gateway == null || !_form.currentState!.validate()) return;
    return _gateway == 'kushki' ? _payKushki() : _payStripe();
  }

  Map<String, String> get _shipping => {
        for (final e in _c.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      };

  void _start() => setState(() {
        _busy = true;
        _error = null;
      });

  /// Pago terminado (o aceptado y pendiente de confirmar): vuelve al inicio con un mensaje.
  Future<void> _finish(String message) async {
    final cart = context.read<CartState>();
    final orders = context.read<OrdersState>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Future.wait([cart.refresh(), orders.sync()]);
    nav.popUntil((route) => route.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
  }

  Future<void> _payKushki() async {
    final publicId = _kushki['public_id'] as String?;
    if (publicId == null || publicId.isEmpty) {
      setState(() => _error = 'Kushki no está configurado en el servidor.');
      return;
    }
    _start();
    final api = context.read<Api>();
    final cart = context.read<CartState>();
    var tokenized = false;
    try {
      // El token se pide por el total vigente en el servidor, no por el que quedó en pantalla.
      await cart.refresh();
      final token = await KushkiClient(publicId: publicId, production: _kushki['env'] == 'production').tokenize(
        name: _card['name']!.text.trim(),
        number: _card['number']!.text,
        expiryMonth: _card['month']!.text.trim(),
        expiryYear: _card['year']!.text.trim(),
        cvv: _card['cvv']!.text.trim(),
        totalAmount: cart.cart.total,
      );
      tokenized = true;
      final parts = _c['full_name']!.text.trim().split(RegExp(r'\s+'));
      final r = await api.post('/checkout/kushki', {
        ..._shipping,
        'token': token,
        'document_type': _docType,
        'document_number': _card['doc']!.text.trim(),
        'first_name': parts.first,
        'last_name': parts.length > 1 ? parts.sublist(1).join(' ') : parts.first,
      });
      if (mounted) await _finish('¡Pedido ${r['code']} pagado!');
    } on ApiException catch (e) {
      // Sin respuesta tras enviar la tarjeta no se sabe si se cobró: no invitar a pagar de nuevo a ciegas.
      final unknown = tokenized && (e.isNetwork || e.statusCode == 502);
      if (mounted) {
        setState(() => _error = unknown
            ? 'No pudimos confirmar el pago. Revisa "Mis pedidos" en unos minutos antes de volver a intentarlo.'
            : e.message);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payStripe() async {
    _start();
    final api = context.read<Api>();
    final Map<String, dynamic> r;
    try {
      r = await api.post('/checkout/intent', _shipping);
      Stripe.publishableKey = r['publishable_key'];
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: r['client_secret'],
          merchantDisplayName: 'Mi Tienda',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      // Cancelar la hoja de pago no es un error.
      if (mounted) {
        setState(() {
          _busy = false;
          if (e.error.code != FailureCode.Canceled) _error = e.error.localizedMessage ?? 'No se pudo completar el pago.';
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
      return;
    }

    // A partir de aquí Stripe YA aceptó el pago: ningún error posterior debe mostrarse como un pago
    // fallido (el usuario pagaría dos veces). Si el servidor no lo confirma aún, lo hará el webhook.
    var paid = false;
    try {
      final c = await api.post('/orders/${r['order_id']}/confirm-payment');
      paid = c['paid'] == true;
    } catch (_) {}
    if (!mounted) return;
    await _finish(paid
        ? '¡Pedido ${r['code']} pagado!'
        : 'Pago recibido. El pedido ${r['code']} se confirmará en unos segundos.');
  }

  String? _req(String? v) => v == null || v.trim().isEmpty ? 'Requerido' : null;

  String? _cardNumber(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^\d{13,19}$').hasMatch(d) ? null : 'Número no válido';
  }

  String? _month(String? v) {
    final m = int.tryParse((v ?? '').trim());
    return m != null && m >= 1 && m <= 12 ? null : 'Mes 01-12';
  }

  String? _year(String? v) => RegExp(r'^(\d{2}|\d{4})$').hasMatch((v ?? '').trim()) ? null : 'AA';

  String? _cvv(String? v) => RegExp(r'^\d{3,4}$').hasMatch((v ?? '').trim()) ? null : '3-4 dígitos';

  static final _digits = [FilteringTextInputFormatter.digitsOnly];

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
              keyboardType: switch (e.key) {
                'email' => TextInputType.emailAddress,
                'phone' => TextInputType.phone,
                _ => TextInputType.text,
              },
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
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(23)],
                decoration: const InputDecoration(labelText: 'Número de tarjeta'),
                validator: _cardNumber),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: TextFormField(
                      controller: _card['month'],
                      keyboardType: TextInputType.number,
                      inputFormatters: [..._digits, LengthLimitingTextInputFormatter(2)],
                      decoration: const InputDecoration(labelText: 'Mes (MM)'),
                      validator: _month)),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                      controller: _card['year'],
                      keyboardType: TextInputType.number,
                      inputFormatters: [..._digits, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(labelText: 'Año (AA)'),
                      validator: _year)),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                      controller: _card['cvv'],
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [..._digits, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(labelText: 'CVV'),
                      validator: _cvv)),
            ]),
            Row(children: [
              DropdownButton<String>(
                value: _docType,
                items: const [
                  DropdownMenuItem(value: 'CC', child: Text('Cédula')),
                  DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                  DropdownMenuItem(value: 'PP', child: Text('Pasaporte')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _docType = v!),
              ),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _card['doc'], decoration: const InputDecoration(labelText: 'N.º de documento'), validator: _req)),
            ]),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 20),
          if (_gatewayFailed)
            OutlinedButton.icon(
              onPressed: _loadGateway,
              icon: const Icon(Icons.refresh),
              label: const Text('No se pudo preparar el pago. Reintentar'),
            )
          else
            FilledButton(
              onPressed: _busy || _gateway == null || total <= 0 ? null : _pay,
              child: _busy || _gateway == null
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Pagar \$${total.toStringAsFixed(2)}'),
            ),
        ]),
      ),
    );
  }
}
