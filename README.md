# Mi Tienda (Flutter)

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

Pagos: solo Stripe. Kushki (Ecuador) no está en la API. El pago con tarjeta no se ha probado de extremo a extremo;
requiere `STRIPE_KEY`/`STRIPE_SECRET` en la web. Android usa `FlutterFragmentActivity` y tema AppCompat (requisito de flutter_stripe).
