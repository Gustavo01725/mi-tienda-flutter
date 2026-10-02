import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  bool _register = false, _busy = false;
  String? _error;

  Future<void> _submit() async {
    final auth = context.read<AuthState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await auth.register(_name.text.trim(), _email.text.trim(), _pass.text);
      } else {
        await auth.login(_email.text.trim(), _pass.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Crear cuenta' : 'Iniciar sesión')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (_register) TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo')),
        TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_register ? 'Registrarme' : 'Entrar')),
        TextButton(
          onPressed: () => setState(() => _register = !_register),
          child: Text(_register ? 'Ya tengo cuenta' : 'Crear una cuenta'),
        ),
      ]),
    );
  }
}
