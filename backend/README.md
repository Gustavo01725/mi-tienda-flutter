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
