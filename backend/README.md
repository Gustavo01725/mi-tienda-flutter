# Parche API para la web Laravel (`mi-tienda`)

La web no tiene API (solo Blade). Estos archivos añaden una API REST con Sanctum
sobre **la misma base de datos y modelos**, que es lo que consume la app Flutter.
Copia el contenido de esta carpeta dentro del repo web, respetando rutas.

## Pasos

1. `composer require laravel/sanctum` y `php artisan install:api`
   (crea `routes/api.php` y la migración de `personal_access_tokens`; sustituye `routes/api.php` por el de aquí).
   Luego `php artisan migrate`.
2. En `app/Models/User.php` añade `use Laravel\Sanctum\HasApiTokens;` y `use HasApiTokens` en la clase.
3. En `app/Models/ProductStock.php` añade `protected $touches = ['product'];`
   Así cualquier cambio de stock (venta en la web, edición del vendedor) actualiza
   `products.updated_at` y la app lo recibe en el siguiente ciclo de sincronización.
4. En `bootstrap/app.php` registra los alias de middleware:
   ```php
   $middleware->alias([
       'seller' => \App\Http\Middleware\EnsureSellerApi::class,
       'admin.api' => \App\Http\Middleware\EnsureAdminApi::class,
   ]);
   ```
5. Producción: `php artisan storage:link` ya usado por `uploaded_asset()`; `APP_URL` debe ser la URL pública
   (las imágenes se devuelven como URL absoluta).

## Tiempo real

Por defecto la app hace *polling* incremental a `GET /api/sync/products?since=` cada ~5 s
(sin infraestructura extra). Para push inmediato, instala Laravel Reverb
(`php artisan install:broadcasting`) y emite un evento en `Product`/`ProductStock` `saved`;
la app solo tendría que disparar el mismo `sync()` al recibirlo.

## Base de datos

La web usa SQLite por defecto en `.env.example`. Para que web y app compartan datos en
producción la web debe estar desplegada (la app solo habla con la API, nunca con la BD).

## Carrito, checkout y pedidos

- `routes/api.php` incluye `/cart`, `/checkout/intent`, `/orders`, `/sync/orders` y `/seller/orders*`.
- **Pagos:** solo Stripe (PaymentSheet). La web debe tener `STRIPE_KEY`, `STRIPE_SECRET` y el webhook `payment_intent.succeeded`
  configurados (ya los usa). Kushki (Ecuador): `GET /api/checkout/gateway` devuelve la pasarela por IP (igual que la web) y `POST /api/checkout/kushki` cobra con el token que genera la app (`KUSHKI_*` en `.env`). La tarjeta se tokeniza en la app directamente contra Kushki.
- En `Order` y `OrderDetail` el cambio de estado debe pasar por `Order::update()` (como ya hace la web) para que `updated_at`
  avance y `/api/sync/orders` lo entregue a la app.

## Notificaciones

`/api/notifications` expone la tabla `notifications` (los avisos que la web ya genera: pedido confirmado/en almacén,
nueva venta, tienda aprobada, liquidación). No requiere cambios en la web. La app los consulta con el mismo ciclo de 5 s
y los muestra como notificación del sistema mientras está abierta o en segundo plano reciente.
Push con la app cerrada requiere Firebase (FCM); ver README principal.

## Push con Firebase (FCM)

1. En la consola de Firebase crea un proyecto y añade la app Android (`com.mitienda.mi_tienda`, o el id que uses).
   Descarga `google-services.json` → `android/app/` del repo Flutter. Para iOS, `GoogleService-Info.plist` y subir la clave APNs.
2. Project settings → Service accounts → *Generate new private key*. Guarda el JSON **fuera de git** en el servidor web.
3. En la web: `composer require kreait/laravel-firebase` y en `.env`: `FIREBASE_CREDENTIALS=/ruta/segura/service-account.json`.
4. Copia `database/migrations/…device_tokens…`, `app/Models/DeviceToken.php`, `app/Listeners/SendPushForNotification.php`,
   `DeviceController` y `routes/api.php`; ejecuta `php artisan migrate`.
5. El listener se descubre solo (Laravel 11/12 registra las clases de `app/Listeners` por el tipo de `handle()`): **no lo registres a mano**
   o cada aviso se enviaría dos veces. Mientras `kreait/laravel-firebase` no esté instalado, no hace nada.
   No hay que tocar las clases de notificación existentes: el listener reenvía como push cada aviso de `database`.

## Pruebas

`tests/Feature/Api/` trae pruebas de la API (auth, carrito, checkout con Stripe/Kushki simulados, pedidos, sync,
permisos y push). Cópialas a la web y corre `php artisan test`: usan los mismos ayudantes que las pruebas de la web
(`Tests\Concerns\BuildsCheckoutData`). La de push se omite si `kreait/laravel-firebase` no está instalado.
Verificado con la suite completa de la web: 233 pruebas en verde (con kreait/laravel-firebase 7.2 / firebase-php 8.5).

## Seguridad y límites

- Inicio de sesión: 5 contraseñas fallidas por minuto por correo+IP, y 60 peticiones por minuto por IP (las redes
  móviles con CGNAT comparten IP: un límite bajo por IP bloquearía a usuarios legítimos).
- Checkout: un solo pago a la vez por usuario (lock en caché; la web usa `CACHE_STORE=database`, que lo soporta).
  Un pedido con un pago de Stripe en curso no se modifica ni se cobra por Kushki.
- Un vendedor solo ve pedidos pagados que llevan productos suyos, y solo sus líneas.
