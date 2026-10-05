# Lista de verificación en dispositivo / emulador

Marca cada punto. Si algo falla, ve a **Si falla** al final: los puntos de riesgo conocidos están señalados con ⚠️.

## 0. Antes de empezar

- [ ] Android Studio con un emulador (API 33+) o un teléfono con depuración USB.
- [ ] `flutter doctor` sin errores en *Android toolchain*.
- [ ] Web local arriba: `tool/local-test/setup.sh` y luego `cd .local-web && php artisan serve --host=0.0.0.0 --port=8000`.
- [ ] `bash tool/local-test/e2e.sh` (desde `.local-web`) termina con todo lo esperado. Si esto falla, la app no tiene nada que probar.
- [ ] Claves **de prueba** en `.local-web/.env`: `STRIPE_KEY`, `STRIPE_SECRET`, `KUSHKI_ENV=test`, `KUSHKI_PUBLIC_MERCHANT_ID`, `KUSHKI_PRIVATE_MERCHANT_ID`. Luego `php artisan config:clear`.
- [ ] Emulador: `API_URL=http://10.0.2.2:8000`. Teléfono real: la IP de tu PC en la red (`http://192.168.x.x:8000`) y ambos en la misma wifi.

```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

## 1. Compila y arranca  ⚠️ (cambios nativos sin probar)

- [ ] Compila sin errores de Gradle (desugaring de notificaciones, `FlutterFragmentActivity`, tema AppCompat de Stripe).
- [ ] La app abre y muestra el catálogo con la Camiseta ($18.00, tachado $20.00).
- [ ] Sin `google-services.json` la app arranca igual (push desactivado, sin crash).

## 2. Sesión

- [ ] Registro con un correo nuevo → entra y queda como cliente. Ese usuario aparece en la web local (admin → usuarios).
- [ ] Cerrar sesión y entrar con `cust@t.com` / `secret123`.
- [ ] Contraseña incorrecta → mensaje de error, sin crash.
- [ ] Cerrar y reabrir la app → la sesión se conserva.

## 3. Sincronización web ↔ app (≤ 5 s, sin tocar la app)

Con la app abierta en el catálogo y el detalle del producto:

- [ ] En la web (o con la API como vendedor) cambia el stock de una variante → el chip se actualiza solo.
- [ ] Despublica el producto → desaparece del catálogo. Vuelve a publicarlo → reaparece.
- [ ] Cambia el precio o el descuento → el precio de la tarjeta cambia.
- [ ] Crea un producto nuevo → aparece.
- [ ] Una variante que se agota mientras la miras queda deshabilitada y se deselecciona.
- [ ] Modo avión → aparece el aviso de conexión con **Reintentar**; al volver la red se recupera solo.

## 4. Carrito

- [ ] Sin elegir variante → "Elige talla y color".
- [ ] M-negro ×2 → carrito: subtotal $36, envío $2, total $38.
- [ ] Más unidades que el stock → error "Solo hay N unidades".
- [ ] `+` se deshabilita en el tope de stock; `−` no baja de 1; el icono de papelera quita el ítem.
- [ ] Añade un ítem **en la web** (misma cuenta) → aparece en la app en ≤ 5 s, y al revés.
- [ ] El contador del icono del carrito coincide.

## 5. Pago con Stripe  ⚠️ (no probado de extremo a extremo)

El checkout usa Stripe cuando la API dice `gateway: stripe` (IP no ecuatoriana). Ojo: en local la web asume Ecuador (`EC`)
y responde `kushki`. Para forzar Stripe prueba con `app.env=production` o cambia `GeolocationService` temporalmente.

- [ ] Datos de envío obligatorios: vacíos → "Requerido".
- [ ] **Pagar** abre el PaymentSheet de Stripe.
- [ ] Tarjeta `4242 4242 4242 4242`, cualquier fecha futura y CVC → pago aprobado.
- [ ] Vuelve a la pantalla principal con "¡Pedido ORD-… pagado!", el carrito queda vacío.
- [ ] El pedido aparece como **Pagado** en la app y en la web; el stock bajó.
- [ ] Tarjeta rechazada `4000 0000 0000 0002` → mensaje de error, el pedido sigue sin pagar y el carrito intacto.
- [ ] Cerrar el PaymentSheet sin pagar → sin error rojo.
- [ ] En la web, con el webhook de Stripe configurado (`stripe listen --forward-to …/webhooks/stripe`), el pedido se marca pagado aunque la app se cierre justo después de pagar.

## 6. Pago con Kushki (Ecuador)  ⚠️ (tokenización escrita sin poder verificarla)

- [ ] El formulario de tarjeta aparece (nombre, número, MM, AA, CVV, tipo y número de documento).
- [ ] Tarjeta de pruebas de Kushki UAT (pídela en su portal) → pedido pagado, mismo resultado que en Stripe.
- [ ] Si el token falla, el mensaje muestra lo que respondió Kushki. Corrige solo `lib/services/kushki_client.dart`.
- [ ] Tarjeta rechazada → error claro, pedido sin pagar.
- [ ] Comprueba en el log de Laravel (`storage/logs/laravel.log`) que **no** aparecen números de tarjeta.

## 7. Pedidos y vendedor

Como cliente:
- [ ] **Pedidos** lista el pedido con estado "Pagado · Pendiente"; el detalle muestra líneas, variante, total y dirección.

Como vendedor (`seller@t.com`):
- [ ] **Inventario** muestra sus productos; editar cantidades y guardar → se ve en la web y en el catálogo del cliente.
- [ ] Pestaña **Mis ventas** con el pedido pagado.
- [ ] **Confirmar pedido** → estado "Confirmado" (de nuevo, el botón desaparece). **Enviar al almacén** → "En almacén".
- [ ] El cliente ve el cambio de estado en ≤ 5 s sin recargar.

Como administrador (`admin@t.com`):
- [ ] Icono de usuarios con la lista; un usuario nuevo creado en la web aparece solo.
- [ ] Un cliente **no** ve los iconos de inventario ni usuarios.

## 8. Avisos y notificaciones

- [ ] Concede el permiso de notificaciones cuando lo pida (Android 13+).
- [ ] Con la app abierta: el vendedor confirma el pedido → el cliente recibe una notificación del sistema "Tu pedido… confirmado" y la campana sube a 1.
- [ ] Al abrir **Avisos** la lista muestra los mensajes; tocar uno de pedido abre su detalle.
- [ ] **Marcar leídos** deja el contador en 0 (y el banner de la web también desaparece: es la misma tabla).
- [ ] Al abrir la app NO llegan en bloque los avisos viejos.

## 9. Push con la app cerrada (Firebase, opcional)

Requiere `google-services.json` en `android/app/`, `kreait/laravel-firebase` en la web y `FIREBASE_CREDENTIALS` (ver `backend/README.md`).

- [ ] Tras iniciar sesión, `device_tokens` en la BD tiene una fila para el usuario.
- [ ] App en segundo plano: el vendedor confirma un pedido → llega **un solo** push (sin duplicado local).
- [ ] App cerrada del todo: llega el push; al tocarlo abre la app.
- [ ] Cerrar sesión → la fila de `device_tokens` desaparece y ese teléfono ya no recibe avisos de esa cuenta.
- [ ] Si no se envía nada: mira `laravel.log` por `FCM: no se pudo enviar` (credenciales o `FIREBASE_CREDENTIALS` mal puestas).

## 10. Seguridad y permisos (con curl, token de cliente)

- [ ] `GET /api/sync/users` → 403. `GET /api/seller/products` → 403.
- [ ] `GET /api/orders/<id de otro usuario>` → 404.
- [ ] Tras cerrar sesión el token anterior responde 401.
- [ ] `APP_DEBUG=false` en producción (con `true` los errores 403 devuelven el stacktrace).
- [ ] Producción: `API_URL` con **https** (Android bloquea http salvo en emulador/desarrollo).

## Si falla

| Síntoma | Causa probable |
|---|---|
| "Sin conexión con el servidor" | `API_URL` mal (usa `10.0.2.2` en emulador), servidor sin `--host=0.0.0.0`, o http bloqueado en el teléfono |
| Error de Gradle con *desugaring* / `compileSdk` | `android/app/build.gradle.kts` (desugar_jdk_libs) o versión de Android SDK |
| Crash al abrir el PaymentSheet | `MainActivity` debe ser `FlutterFragmentActivity` y el tema AppCompat (`styles.xml`) |
| Sync no trae cambios | Cambió el stock por SQL directo: el cursor usa `updated_at`; usa Eloquent o toca `products.updated_at` |
| 422 "Esa combinación no está disponible" | La clave de variante no coincide con `product_stocks.variant` (se calcula con `size-color`) |
| 429 al iniciar sesión | Límite de 10 intentos por minuto (`throttle:10,1`) |
| Imágenes sin cargar | `php artisan storage:link` y `APP_URL` correcto en la web |

Cuando todo esté marcado, el siguiente paso es producción: web con HTTPS, `APP_DEBUG=false`, claves reales y webhook de Stripe/Kushki apuntando a la web pública.
