# Mi Tienda (Flutter)

La app replica el diseño de la web **guStore**: mismos logos (`assets/img/`, copiados de `public/assets/img`),
fuente Open Sans, iconos Line Awesome, verde `#679941`, banner superior, barra de idioma/sesión, cabecera con
pestañas Inicio / Productos / Pedidos / Billetera y la barra inferior con el carrito en el centro. Cada pantalla
sigue su vista Blade: portada por secciones, productos, ficha (talla, color, cantidad), carrito, Secure Checkout,
Mis pedidos, billetera, categorías, notificaciones, Mi perfil, login y registro.

App móvil de la tienda web Laravel `gustavoryanflow45-hub/mi-tienda`. Comparte la misma base de datos
a través de una API REST (la app nunca se conecta directo a la BD).

- `backend/` — parche con la API (Sanctum) que hay que aplicar a la web. Ver `backend/README.md`.
- `lib/` — app: catálogo con sincronización incremental cada 5 s, detalle con stock por variante en vivo,
  login/registro (mismos usuarios que la web), inventario de vendedor/admin y lista de usuarios (admin).

## Ejecutar

```bash
flutter pub get
flutter run --dart-define=API_URL=https://tu-dominio.com   # emulador Android local: http://10.0.2.2:8000
```

Los cambios hechos en la web (productos, stock, usuarios) aparecen en la app en ≤5 s y viceversa.
Carrito (compartido con la web), checkout con Stripe PaymentSheet, historial de pedidos y gestión de
pedidos del vendedor (confirmar / enviar al almacén) sincronizados cada 5 s.

Pagos: Stripe (resto del mundo) y Kushki (Ecuador), elegidos por la API según el país, igual que la web. Ninguno se ha probado de extremo a extremo;
requiere `STRIPE_KEY`/`STRIPE_SECRET` en la web. Android usa `FlutterFragmentActivity` y tema AppCompat (requisito de flutter_stripe).

## Notificaciones

Centro de avisos (campana) alimentado por la tabla `notifications` de la web, y notificaciones del sistema.
Con la app abierta las muestra `flutter_local_notifications`; con la app en segundo plano o cerrada llegan por **push de
Firebase (FCM)**, que es opcional: sin `google-services.json` la app compila y funciona igual, solo sin push de fondo.
Configuración paso a paso en `backend/README.md` → *Push con Firebase*.
