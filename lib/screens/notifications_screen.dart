import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notifications_state.dart';
import 'order_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationsState>();
    final items = state.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          if (state.unread > 0)
            TextButton(onPressed: () => state.markAllRead().catchError((_) {}), child: const Text('Marcar leídos')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.sync,
        child: items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Sin avisos'))])
            : ListView(children: [
                for (final n in items)
                  ListTile(
                    leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active, color: n.read ? null : Colors.deepOrange),
                    title: Text(n.title, style: TextStyle(fontWeight: n.read ? null : FontWeight.bold)),
                    subtitle: Text(n.message),
                    onTap: n.orderId == null
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: n.orderId!))),
                  ),
              ]),
      ),
    );
  }
}
