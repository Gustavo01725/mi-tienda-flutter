import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/api.dart';
import '../services/auth_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'inventory_screen.dart';
import 'login_screen.dart';
import 'users_screen.dart';

/// "Mi perfil" (users/profile.blade.php) y accesos del vendedor/administrador.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _profile = GlobalKey<FormState>(), _pwForm = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _phone = TextEditingController();
  final _current = TextEditingController(), _pass = TextEditingController(), _pass2 = TextEditingController();
  int? _loadedFor;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _current, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(AppUser u) {
    _loadedFor = u.id;
    _name.text = u.name;
    _email.text = u.email;
    _phone.text = u.phone ?? '';
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final profileOk = _profile.currentState!.validate();
    final wantsPassword = _pass.text.isNotEmpty || _pass2.text.isNotEmpty;
    final pwOk = !wantsPassword || _pwForm.currentState!.validate();
    if (!profileOk || !pwOk) return;
    setState(() => _saving = true);
    final api = context.read<Api>();
    final auth = context.read<AuthState>();
    try {
      final r = await api.put('/profile', {'name': _name.text.trim(), 'email': _email.text.trim(), 'phone': _phone.text.trim()});
      auth.updateUser(AppUser.fromJson(r));
      if (wantsPassword) {
        await api.put('/profile/password', {
          'current_password': _current.text,
          'password': _pass.text,
          'password_confirmation': _pass2.text,
        });
        _current.clear();
        _pass.clear();
        _pass2.clear();
      }
      _snack(wantsPassword ? 'Perfil y contraseña actualizados correctamente.' : 'Perfil actualizado correctamente.');
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final u = auth.user;
    if (u == null) return const LoginScreen(embedded: true, active: AppPage.account);
    if (_loadedFor != u.id) _fill(u);

    Widget link(IconData icon, String label, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              const Icon(LineAwesomeIcons.angle_right_solid, size: 14, color: AppColors.muted3),
            ]),
          ),
        );

    return GuScaffold(
      active: AppPage.account,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 28, 15, 16),
            child: Row(children: [
              const Icon(LineAwesomeIcons.user_circle, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              const Text('Mi perfil', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const Spacer(),
              Pill(
                switch (u.userType) { 'admin' => 'Administrador', 'seller' => 'Vendedor', _ => 'Cliente' },
                color: AppColors.primary,
                background: AppColors.softPrimary,
              ),
            ]),
          ),
        ),
        if (!u.verified)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(15, 0, 15, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                border: Border.all(color: const Color(0xFFFFD8A8)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Verifica tu correo electrónico: te enviamos un enlace al registrarte.', style: TextStyle(fontSize: 13)),
            ),
          ),
        SliverToBoxAdapter(
          child: GuCard(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Form(
                key: _profile,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  LabeledField(label: 'Nombre completo', controller: _name, validator: (v) => (v ?? '').trim().isEmpty ? 'El nombre es obligatorio.' : null),
                  LabeledField(
                    label: 'Correo electrónico',
                    controller: _email,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) => (v ?? '').contains('@') ? null : 'El correo es obligatorio.',
                  ),
                  LabeledField(label: 'Teléfono', controller: _phone, keyboard: TextInputType.phone),
                ]),
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text('Dejar en blanco para mantener la contraseña actual.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 16),
              Form(
                key: _pwForm,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  LabeledField(
                    label: 'Contraseña actual',
                    controller: _current,
                    obscure: true,
                    validator: (v) => (v ?? '').isEmpty ? 'Ingresa tu contraseña actual.' : null,
                  ),
                  LabeledField(
                    label: 'Nueva contraseña',
                    controller: _pass,
                    obscure: true,
                    validator: (v) => (v ?? '').length < 8 ? 'Mínimo 8 caracteres.' : null,
                  ),
                  LabeledField(
                    label: 'Confirmar nueva contraseña',
                    controller: _pass2,
                    obscure: true,
                    validator: (v) => v != _pass.text ? 'Las contraseñas no coinciden.' : null,
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cambios'),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: GuCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              if (u.isSeller || u.isAdmin) ...[
                link(LineAwesomeIcons.boxes_solid, 'Mi inventario',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()))),
                const Divider(),
              ],
              if (u.isAdmin) ...[
                link(LineAwesomeIcons.users_solid, 'Usuarios',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()))),
                const Divider(),
              ],
              link(LineAwesomeIcons.file_alt, 'Mis pedidos', () => context.read<NavState>().go(AppPage.orders)),
              const Divider(),
              link(LineAwesomeIcons.wallet_solid, 'Billetera', () => context.read<NavState>().go(AppPage.wallet)),
              const Divider(),
              link(LineAwesomeIcons.sign_out_alt_solid, 'Cerrar sesión', () async {
                await auth.logout();
                if (context.mounted) context.read<NavState>().go(AppPage.home);
              }),
            ]),
          ),
        ),
      ],
    );
  }
}
