import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config.dart';
import '../models/app_notification.dart';
import 'api.dart';

/// Avisos del usuario (tabla `notifications` de la web). Cada aviso nuevo se muestra
/// además como notificación del sistema. La primera carga no dispara avisos: solo los
/// que lleguen después, para no bombardear con el historial al abrir la app.
class NotificationsState extends ChangeNotifier {
  final Api api;
  NotificationsState(this.api, {this.pushActive});

  /// Si FCM está operativo, en segundo plano el aviso lo muestra el push y no este servicio
  /// (evita la notificación duplicada).
  final bool Function()? pushActive;

  final _plugin = FlutterLocalNotificationsPlugin();
  final Map<String, AppNotification> _items = {};
  String? _since;
  int unread = 0;
  Timer? _timer;
  bool _active = false, _busy = false, _ready = false, _firstLoad = true;

  List<AppNotification> get items => _items.values.toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  void setLoggedIn(bool loggedIn) {
    if (loggedIn == _active) return;
    _active = loggedIn;
    _timer?.cancel();
    if (loggedIn) {
      _init().catchError((_) {}); // sin permiso se sigue viendo la lista dentro de la app
      sync();
      _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) => sync());
    } else {
      _items.clear();
      _since = null;
      unread = 0;
      _firstLoad = true;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    if (_busy) return;
    _busy = true;
    try {
      final r = await api.get('/notifications', {if (_since != null) 'since': _since!});
      final fresh = <AppNotification>[];
      for (final j in r['data'] as List) {
        final n = AppNotification.fromJson(j);
        if (!_items.containsKey(n.id)) fresh.add(n);
        _items[n.id] = n;
      }
      _since = r['server_time'];
      final newUnread = r['unread_count'] as int;
      final changed = fresh.isNotEmpty || newUnread != unread;
      unread = newUnread;
      if (!_firstLoad) {
        for (final n in fresh) {
          _show(n);
        }
      }
      _firstLoad = false;
      if (changed) notifyListeners();
    } on ApiException {
      // se reintenta en el siguiente ciclo
    } finally {
      _busy = false;
    }
  }

  Future<void> _show(AppNotification n) async {
    if (!_ready) return;
    final foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!foreground && (pushActive?.call() ?? false)) return;
    try {
      await _plugin.show(
        id: n.id.hashCode & 0x7fffffff,
        title: n.title,
        body: n.message,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('orders', 'Pedidos y ventas',
              importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    await api.post('/notifications/read-all');
    await sync();
    for (final n in _items.values.toList()) {
      _items[n.id] = AppNotification.fromJson({
        'id': n.id, 'message': n.message, 'type': n.type, 'order_id': n.orderId,
        'read': true, 'created_at': n.createdAt?.toIso8601String(),
      });
    }
    unread = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
