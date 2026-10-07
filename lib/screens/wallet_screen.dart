import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/auth_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'login_screen.dart';

/// Billetera (users/wallet.blade.php): saldo, accesos a recargar/retirar e historial.
/// Recargar y retirar abren la web, que tiene esos formularios (comprobante, datos bancarios).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  int? _loadedFor;

  Future<void> _load() async {
    try {
      final r = await context.read<Api>().get('/wallet');
      if (mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(r);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    if (user == null) return const LoginScreen(embedded: true, active: AppPage.wallet);
    if (_loadedFor != user.id) {
      _loadedFor = user.id;
      _data = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final balance = ((_data?['balance'] ?? 0) as num).toDouble();

    Widget action(String label, String path) => GuCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: () => openWeb(context, path),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Color(0xFFCED2DA), shape: BoxShape.circle),
                  child: const Icon(LineAwesomeIcons.plus_solid, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );

    String statusLabel(String s) => switch (s) { 'approved' => 'Aprobado', 'pending' => 'Pendiente', _ => 'Rechazado' };

    Widget history(String title, List items) => GuCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Divider(),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Sin movimientos todavía.', style: TextStyle(color: AppColors.muted3)),
              ),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(money((it['amount'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text((it['created_at'] ?? '').toString().split('T').first,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted2)),
                    ]),
                  ),
                  Pill.status(statusLabel('${it['status']}'), ok: it['status'] == 'approved', warn: it['status'] == 'pending'),
                ]),
              ),
          ]),
        );

    return GuScaffold(
      active: AppPage.wallet,
      onRefresh: _load,
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(15, 24, 15, 20),
            padding: const EdgeInsets.symmetric(vertical: 34),
            decoration: BoxDecoration(gradient: AppColors.walletGradient, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Text('\$', style: TextStyle(color: Colors.white70, fontSize: 30, fontWeight: FontWeight.w300)),
              const SizedBox(height: 4),
              Text(money(balance), style: const TextStyle(color: Colors.white, fontSize: 41.6, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Saldo de la billetera', style: TextStyle(color: Colors.white, fontSize: 14.4)),
            ]),
          ),
        ),
        if (_error != null)
          SliverToBoxAdapter(child: GuCard(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))),
        SliverToBoxAdapter(child: action('Recargar billetera', '/wallet')),
        SliverToBoxAdapter(child: action('Enviar solicitud de retiro', '/wallet')),
        SliverToBoxAdapter(child: history('Historial de recargas', (_data?['recharges'] as List?) ?? const [])),
        SliverToBoxAdapter(child: history('Historial de retiros', (_data?['withdrawals'] as List?) ?? const [])),
      ],
    );
  }
}
