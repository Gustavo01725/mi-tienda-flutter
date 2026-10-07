import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../services/kushki_client.dart';
import '../services/nav_state.dart';
import '../services/orders_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';

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
    'email': 'Correo electrónico',
    'address': 'Dirección',
    'city': 'Ciudad',
    'state': 'Provincia / Estado',
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
    final nav = context.read<NavState>();
    final messenger = ScaffoldMessenger.of(context);
    await Future.wait([cart.refresh(), orders.sync()]);
    nav.go(AppPage.orders);
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
    final cart = context.watch<CartState>().cart;
    final total = cart.total;
    const title = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

    Widget field(String key) => LabeledField(
          label: '${_fields[key]}${_optional.contains(key) ? '' : ' *'}',
          controller: _c[key]!,
          keyboard: switch (key) {
            'email' => TextInputType.emailAddress,
            'phone' => TextInputType.phone,
            _ => TextInputType.text,
          },
          validator: (v) => !_optional.contains(key) && (v == null || v.trim().isEmpty) ? 'Requerido' : null,
        );

    Widget small(TextEditingController c, String label, String? Function(String?) v, {int max = 4, bool obscure = false}) =>
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: c,
              keyboardType: TextInputType.number,
              obscureText: obscure,
              inputFormatters: [..._digits, LengthLimitingTextInputFormatter(max)],
              validator: v,
            ),
          ]),
        );

    return GuScaffold(
      active: AppPage.cart,
      slivers: [
        SliverToBoxAdapter(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(15, 22, 15, 16),
                child: Row(children: [
                  Icon(LineAwesomeIcons.lock_solid, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Secure Checkout', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                ]),
              ),
              GuCard(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Row(children: [
                    Icon(LineAwesomeIcons.truck_solid, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Datos de envío', style: title),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 16),
                  for (final k in _fields.keys) field(k),
                ]),
              ),
              GuCard(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Datos de pago', style: title),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (_gateway == null && !_gatewayFailed)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_gateway == 'stripe')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Al pulsar "Pagar" se abrirá el formulario seguro de Stripe para tu tarjeta.',
                          style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                  if (_gateway == 'kushki') ...[
                    LabeledField(label: 'Nombre en la tarjeta *', controller: _card['name']!, validator: _req),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Número de tarjeta *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _card['number'],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(23)],
                          decoration: const InputDecoration(hintText: '0000 0000 0000 0000'),
                          validator: _cardNumber,
                        ),
                      ]),
                    ),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      small(_card['month']!, 'Mes *', _month, max: 2),
                      const SizedBox(width: 10),
                      small(_card['year']!, 'Año *', _year),
                      const SizedBox(width: 10),
                      small(_card['cvv']!, 'CVV *', _cvv, obscure: true),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Documento *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _docType,
                            style: const TextStyle(fontFamily: 'OpenSans', fontSize: 14, color: AppColors.text),
                            items: const [
                              DropdownMenuItem(value: 'CC', child: Text('Cédula')),
                              DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                              DropdownMenuItem(value: 'PP', child: Text('Pasaporte')),
                            ],
                            onChanged: _busy ? null : (v) => setState(() => _docType = v!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: _card['doc'], validator: _req, decoration: const InputDecoration(hintText: 'Número'))),
                    ]),
                    const SizedBox(height: 18),
                  ],
                  if (_gatewayFailed)
                    OutlinedButton.icon(
                      onPressed: _loadGateway,
                      icon: const Icon(Icons.refresh),
                      label: const Text('No se pudo preparar el pago. Reintentar'),
                    )
                  else if (_gateway != null)
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: _busy || total <= 0 ? null : _pay,
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Pagar ${money(total)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(LineAwesomeIcons.shield_alt_solid, size: 14, color: AppColors.muted3),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Procesado por ${_gateway == 'kushki' ? 'Kushki' : 'Stripe'} — tu tarjeta nunca pasa por nuestros servidores',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted3),
                      ),
                    ),
                  ]),
                ]),
              ),
              GuCard(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Resumen del pedido', style: title),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  for (final i in cart.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 48, height: 48, child: NetImg(i.thumbnail))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              VariantChips(i.parts, fallback: i.variantLabel),
                              Text('× ${i.quantity}', style: const TextStyle(fontSize: 12, color: AppColors.muted2)),
                            ]),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(money(i.subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (i.shippingCost > 0)
                            Text('+ ${money(i.shippingCost)} envío', style: const TextStyle(fontSize: 11, color: AppColors.muted2)),
                        ]),
                      ]),
                    ),
                  const Divider(),
                  const SizedBox(height: 8),
                  SummaryRow('Subtotal', money(cart.subtotal)),
                  SummaryRow('Envío', money(cart.shipping)),
                  SummaryRow('Impuesto', money(cart.tax)),
                  const SizedBox(height: 6),
                  const Divider(),
                  const SizedBox(height: 6),
                  SummaryRow('Total', money(total), big: true, green: true),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('← Editar carrito', style: TextStyle(color: AppColors.muted2, fontWeight: FontWeight.w400)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
