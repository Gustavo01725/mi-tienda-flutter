import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/user.dart';
import '../services/api.dart';

/// Lista de usuarios (solo admin), refrescada con el mismo ciclo que el catálogo.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final Map<int, AppUser> _users = {};
  String? _since, _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
    _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) => _sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    try {
      final r = await context.read<Api>().get('/sync/users', {if (_since != null) 'since': _since!});
      if (!mounted) return;
      setState(() {
        for (final j in r['changed'] as List) {
          final u = AppUser.fromJson(j);
          _users[u.id] = u;
        }
        final all = (r['all_ids'] as List).cast<int>().toSet();
        _users.removeWhere((id, _) => !all.contains(id));
        _since = r['server_time'];
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _users.values.toList()..sort((a, b) => b.id.compareTo(a.id));
    return Scaffold(
      appBar: AppBar(title: Text('Usuarios (${list.length})')),
      body: _error != null && list.isEmpty
          ? Center(child: Text(_error!))
          : ListView(children: [
              for (final u in list)
                ListTile(
                  leading: CircleAvatar(child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase())),
                  title: Text(u.name),
                  subtitle: Text('${u.email} · ${u.userType}'),
                  trailing: u.banned ? const Icon(Icons.block, color: Colors.red) : null,
                ),
            ]),
    );
  }
}
