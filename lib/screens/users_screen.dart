import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/user.dart';
import '../services/api.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

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
      final r = await context.read<Api>().get('/sync/users', {'since': ?_since});
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
    return GuScaffold(
      active: AppPage.account,
      onRefresh: _sync,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 24, 15, 16),
            child: Row(children: [
              const Icon(LineAwesomeIcons.users_solid, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Usuarios (${list.length})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        if (_error != null && list.isEmpty)
          SliverToBoxAdapter(child: GuCard(child: Text(_error!, style: const TextStyle(color: AppColors.danger))))
        else
          SliverToBoxAdapter(
            child: GuCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      ClipOval(child: Image.asset('assets/img/avatar-place.png', width: 36, height: 36)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(list[i].email, style: const TextStyle(fontSize: 12, color: AppColors.muted2)),
                        ]),
                      ),
                      if (list[i].banned)
                        Pill('Suspendido', color: AppColors.danger, background: AppColors.dangerSoft)
                      else
                        Pill(switch (list[i].userType) { 'admin' => 'Admin', 'seller' => 'Vendedor', _ => 'Cliente' },
                            color: AppColors.primary, background: AppColors.softPrimary),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
      ],
    );
  }

}
