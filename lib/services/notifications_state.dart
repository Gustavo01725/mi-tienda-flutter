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

  /// Ver CartState._session: los avisos de la sesión anterior no deben reaparecer ni dispararse.
  int _session = 0;

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
    _session++;
    _timer?.cancel();
    _items.clear();
    _since = null;
    unread = 0;
    _firstLoad = true;
    _busy = false;
    if (loggedIn) {
      _init().catchError((_) {}); // sin permiso se sigue viendo la lista dentro de la app
      sync();
      _timer = Timer.periodic(const Duration(seconds: syncSeconds), (_) => sync());
    }
    notifyListeners();
  }

  Future<void> sync() async {
    if (_busy) return;
    _busy = true;
    final session = _session;
    try {
      final r = await api.get('/notifications', {'since': ?_since});
      if (session != _session) return;
      final fresh = <AppNotification>[];
      var dirty = false;
      for (final j in r['data'] as List) {
        final n = AppNotification.fromJson(j);
        final old = _items[n.id];
        if (old == null) fresh.add(n);
        if (old == null || old.read != n.read) dirty = true;
        _items[n.id] = n;
      }
      _since = r['server_time'];
      final newUnread = r['unread_count'] as int;
      final changed = dirty || newUnread != unread;
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
      if (session == _session) _busy = false;
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
    for (final n in _items.values.toList()) {
      _items[n.id] = n.copyRead();
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
