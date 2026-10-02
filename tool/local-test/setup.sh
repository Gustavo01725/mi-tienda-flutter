#!/usr/bin/env bash
# Levanta una copia local de la web (Laravel + SQLite) con el parche de backend/ aplicado y datos de prueba.
# Uso: tool/local-test/setup.sh [directorio]   (por defecto ./.local-web). Requiere php 8.2+, composer y git.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
WEB="${1:-$HERE/.local-web}"
export COMPOSER_ALLOW_SUPERUSER=1

[ -d "$WEB" ] || git clone --depth 1 https://github.com/gustavoryanflow45-hub/mi-tienda "$WEB"
cd "$WEB"
composer install --no-interaction --no-progress
composer require laravel/sanctum --no-interaction --no-progress
[ -f .env ] || { cp .env.example .env; php artisan key:generate; }
touch database/database.sqlite
php artisan install:api --no-interaction || true

# Parche: API + middleware + modelos
cp -r "$HERE/backend/app/." app/
cp "$HERE/backend/routes/api.php" routes/api.php
cp "$HERE"/backend/database/migrations/*.php database/migrations/
python3 - <<'PY'
import re
p='bootstrap/app.php'; s=open(p).read()
if "EnsureSellerApi" not in s:
    s=s.replace("            'shop.approved'","            'seller' => \\App\\Http\\Middleware\\EnsureSellerApi::class,\n            'admin.api' => \\App\\Http\\Middleware\\EnsureAdminApi::class,\n            'shop.approved'")
open(p,'w').write(s)
p='app/Models/User.php'; s=open(p).read()
if "HasApiTokens" not in s:
    s=s.replace("use Illuminate\\Notifications\\Notifiable;","use Illuminate\\Notifications\\Notifiable;\nuse Laravel\\Sanctum\\HasApiTokens;").replace("use HasFactory, Notifiable;","use HasApiTokens, HasFactory, Notifiable;")
open(p,'w').write(s)
p='app/Models/ProductStock.php'; s=open(p).read()
if "$touches" not in s:
    s=s.replace("    protected $fillable = ['product_id'","    protected $touches = ['product'];\n\n    protected $fillable = ['product_id'",1)
open(p,'w').write(s)
PY

php artisan migrate:fresh --force
(cd "$WEB" && php "$HERE/tool/local-test/seed.php")
cp "$HERE/tool/local-test/pay.php" pay.php
echo
echo "Listo. Web local en $WEB"
echo "  1) Servidor:   (cd $WEB && php artisan serve --port=8000)"
echo "  2) API e2e:    (cd $WEB && bash $HERE/tool/local-test/e2e.sh)"
echo "  3) App contra la API real:  flutter test test/integration --tags live --dart-define=API_URL=http://localhost:8000"
echo "  4) App en emulador Android: flutter run --dart-define=API_URL=http://10.0.2.2:8000"
echo "Usuarios: admin@t.com / seller@t.com / cust@t.com  (clave secret123)"
