import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'register_screen.dart';

/// "¡Bienvenido de nuevo!" (auth/login.blade.php). [embedded]: se muestra dentro de una página que
/// exige sesión (Pedidos, Billetera...), igual que la web redirige al login.
class LoginScreen extends StatefulWidget {
  final bool embedded;
  final AppPage? active;
  const LoginScreen({super.key, this.embedded = false, this.active});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _pass = TextEditingController();
  bool _remember = true, _busy = false, _show = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().login(_email.text.trim(), _pass.text, remember: _remember);
      if (mounted && !widget.embedded) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GuScaffold(
      active: widget.active,
      slivers: [
        SliverToBoxAdapter(
          child: AuthCard(
            title: '¡Bienvenido de nuevo!',
            subtitle: 'Inicia sesión en tu cuenta',
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_error != null) ErrorBox(_error!),
                  LabeledField(
                    label: 'Correo electrónico',
                    controller: _email,
                    hint: 'Escribe tu correo',
                    keyboard: TextInputType.emailAddress,
                    autofill: const [AutofillHints.email],
                    validator: (v) => v == null || !v.contains('@') ? 'Escribe un correo válido' : null,
                  ),
                  LabeledField(
                    label: 'Contraseña',
                    controller: _pass,
                    hint: 'Escribe tu contraseña',
                    obscure: !_show,
                    autofill: const [AutofillHints.password],
                    validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                    suffix: IconButton(
                      icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.muted3),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                  Row(children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                    ),
                    const SizedBox(width: 8),
                    const Text('Recordarme', style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => openWeb(context, '/password/reset'),
                      child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: AppColors.primary, fontSize: 14)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('¿No tienes cuenta? ', style: TextStyle(fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('Regístrate', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta blanca de login/registro con los logos y el título centrado.
class AuthCard extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const AuthCard({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => GuCard(
        margin: const EdgeInsets.fromLTRB(15, 48, 15, 24),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        radius: 4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Image.asset('assets/img/logo.png', height: 40)),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 24),
          child,
        ]),
      );
}

class ErrorBox extends StatelessWidget {
  final String text;
  const ErrorBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8D7DA),
          border: Border.all(color: const Color(0xFFF5C6CB)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFF721C24), fontSize: 13.5)),
      );
}
