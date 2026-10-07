import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'login_screen.dart';

/// "Crear cuenta" (auth/register.blade.php).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(), _last = TextEditingController(), _email = TextEditingController();
  final _phone = TextEditingController(), _pass = TextEditingController(), _pass2 = TextEditingController();
  bool _terms = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_terms) {
      setState(() => _error = 'Debes aceptar los Términos y condiciones y la Política de privacidad.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().register(
            '${_first.text.trim()} ${_last.text.trim()}',
            _email.text.trim(),
            _pass.text,
            phone: _phone.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cuenta creada! Te enviamos un correo para verificar tu dirección.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Requerido' : null;

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: AppColors.primary);
    return GuScaffold(
      slivers: [
        SliverToBoxAdapter(
          child: AuthCard(
            title: 'Crear cuenta',
            subtitle: 'Únete a Woot y empieza a comprar',
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null) ErrorBox(_error!),
                LabeledField(label: 'Nombre', controller: _first, hint: 'Nombre', validator: _required),
                LabeledField(label: 'Apellido', controller: _last, hint: 'Apellido', validator: _required),
                LabeledField(
                  label: 'Correo electrónico',
                  controller: _email,
                  hint: 'Escribe tu correo',
                  keyboard: TextInputType.emailAddress,
                  validator: (v) => v == null || !v.contains('@') ? 'Escribe un correo válido' : null,
                ),
                LabeledField(label: 'Teléfono', controller: _phone, hint: 'Número de teléfono', keyboard: TextInputType.phone),
                LabeledField(
                  label: 'Contraseña',
                  controller: _pass,
                  hint: 'Crea una contraseña',
                  obscure: true,
                  validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                LabeledField(
                  label: 'Confirmar contraseña',
                  controller: _pass2,
                  hint: 'Repite tu contraseña',
                  obscure: true,
                  validator: (v) => v != _pass.text ? 'Las contraseñas no coinciden' : null,
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14), children: [
                      const TextSpan(text: 'Acepto los '),
                      TextSpan(text: 'Términos y condiciones', style: link, recognizer: TapGestureRecognizer()..onTap = () => openWeb(context, '/terms')),
                      const TextSpan(text: ' y la '),
                      TextSpan(
                        text: 'Política de privacidad',
                        style: link,
                        recognizer: TapGestureRecognizer()..onTap = () => openWeb(context, '/privacy-policy'),
                      ),
                    ])),
                  ),
                ]),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('¿Ya tienes cuenta? ', style: TextStyle(fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Iniciar sesión', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
