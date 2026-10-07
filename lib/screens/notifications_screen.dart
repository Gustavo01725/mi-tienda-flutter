import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../services/nav_state.dart';
import '../services/notifications_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

/// Notificaciones: los mismos avisos que los banners de la web (tabla notifications).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthState>().user == null) return const LoginScreen(embedded: true, active: AppPage.notifications);
    final state = context.watch<NotificationsState>();
    final items = state.items;
    return GuScaffold(
      active: AppPage.notifications,
      onRefresh: state.sync,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 22, 8, 12),
            child: Row(children: [
              const Icon(LineAwesomeIcons.bell, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notificaciones', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
              if (state.unread > 0)
                TextButton(onPressed: () => state.markAllRead().catchError((_) {}), child: const Text('Marcar leídas')),
            ]),
          ),
        ),
        if (items.isEmpty)
          const SliverToBoxAdapter(child: GuCard(child: EmptyState(icon: LineAwesomeIcons.bell_slash, text: 'No tienes notificaciones.')))
        else
          SliverToBoxAdapter(
            child: GuCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(),
                  InkWell(
                    onTap: items[i].orderId == null
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: items[i].orderId!))),
                    child: Container(
                      color: items[i].read ? null : const Color(0x0F679941),
                      padding: const EdgeInsets.all(14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: AppColors.softPrimary, borderRadius: BorderRadius.circular(18)),
                          child: Icon(items[i].read ? LineAwesomeIcons.bell : LineAwesomeIcons.bell_solid, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(items[i].title,
                                style: TextStyle(fontWeight: items[i].read ? FontWeight.w600 : FontWeight.w700, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(items[i].message, style: const TextStyle(color: AppColors.textSoft)),
                          ]),
                        ),
                        if (items[i].orderId != null) const Icon(LineAwesomeIcons.angle_right_solid, size: 14, color: AppColors.primary),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ),
      ],
    );
  }
}
