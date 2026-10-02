# Prueba local web ↔ app

`setup.sh` clona la web, le aplica el parche de `backend/` (Sanctum + API), crea una base SQLite con usuarios y un producto
con variantes, y deja todo listo para probar sin Stripe, Kushki ni Firebase.

1. `tool/local-test/setup.sh` (primera vez)
2. `cd .local-web && php artisan serve --port=8000`
3. `bash tool/local-test/e2e.sh` desde `.local-web`: recorre registro/login, catálogo, carrito, pedido, pago simulado,
   flujo del vendedor (confirmar → almacén), avisos y permisos. Cada línea indica qué se espera.
4. `flutter test test/integration --tags live --dart-define=API_URL=http://localhost:8000`: ejecuta los estados y modelos de la
   app contra esa API real.
5. App en emulador: `flutter run --dart-define=API_URL=http://10.0.2.2:8000`.

El pago se simula con `pay.php` (llama a `Order::markPaid`, lo mismo que hace el webhook). Para probar pagos reales usa claves de
**prueba** (`STRIPE_KEY/SECRET`, `KUSHKI_*` con `KUSHKI_ENV=test`) en el `.env` de la web local.
Ojo con `php artisan tinker` en scripts: se queda esperando; los scripts de esta carpeta arrancan Laravel directamente.
`.local-web/` no se sube a git. Para probar en dispositivo sigue `docs/CHECKLIST.md`.

## Prueba de UI sin emulador (Chromium)

Útil donde no hay emulador Android (CI, contenedores sin KVM):

```bash
flutter build web --no-web-resources-cdn --dart-define=API_URL=http://localhost:8000
(cd build/web && python3 -m http.server 8080) &
npm i playwright-core && CHROME=/ruta/a/chrome node tool/local-test/ui-smoke.js
```

Hace login desde la UI, abre un producto, agrega una variante al carrito y, mientras mira el detalle, cambia el stock como vendedor
por la API: el chip de la variante cambia solo en ≤5 s. Limitaciones de la versión web: no hay PaymentSheet de Stripe, ni push, ni
imágenes cross-origin sin CORS.
