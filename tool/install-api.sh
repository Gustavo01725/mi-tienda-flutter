#!/usr/bin/env bash
# Instala en TU web Laravel (gustavoryanflow45-hub/mi-tienda) la API que usa la app.
# No borra datos: solo añade archivos, ajusta 3 archivos de la web y ejecuta las migraciones pendientes.
#
# Uso:  tool/install-api.sh /ruta/a/mi-tienda          (desde la raíz de este repo)
# Haz un commit o copia de la web antes, para poder revisar el diff con `git diff`.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WEB="${1:?Indica la carpeta de la web: tool/install-api.sh /ruta/a/mi-tienda}"
[ -f "$WEB/artisan" ] || { echo "No encuentro $WEB/artisan: ¿es la carpeta de la web Laravel?"; exit 1; }
cd "$WEB"

echo "1/5 Sanctum (tokens de la app)"
if ! grep -q '"laravel/sanctum"' composer.json; then
  composer require laravel/sanctum --no-interaction --no-progress
fi
# install:api crea routes/api.php, config/sanctum.php y la migración personal_access_tokens.
if [ ! -f config/sanctum.php ] || ! ls database/migrations/*personal_access_tokens* >/dev/null 2>&1; then
  php artisan install:api --no-interaction || true
fi

echo "2/5 Archivos de la API"
cp -r "$HERE/backend/app/." app/
cp "$HERE/backend/routes/api.php" routes/api.php
cp "$HERE"/backend/database/migrations/*.php database/migrations/
mkdir -p tests/Feature/Api && cp "$HERE"/backend/tests/Feature/Api/*.php tests/Feature/Api/

echo "3/5 Ajustes en User, ProductStock y bootstrap/app.php"
python3 - <<'PY'
import re, sys
def patch(path, check, old, new):
    s = open(path).read()
    if check in s:
        return
    if old not in s:
        sys.exit(f"No pude modificar {path}: no encontré el texto esperado. Hazlo a mano (ver backend/README.md).")
    open(path, 'w').write(s.replace(old, new, 1))
    print('   modificado', path)

patch('app/Models/User.php', 'HasApiTokens',
      'use Illuminate\\Notifications\\Notifiable;',
      'use Illuminate\\Notifications\\Notifiable;\nuse Laravel\\Sanctum\\HasApiTokens;')
s = open('app/Models/User.php').read()
if 'use HasApiTokens' not in s:
    s2 = re.sub(r'use HasFactory, Notifiable;', 'use HasApiTokens, HasFactory, Notifiable;', s, count=1)
    if s2 == s:
        sys.exit('No pude añadir HasApiTokens a User: añade "use HasApiTokens;" dentro de la clase.')
    open('app/Models/User.php', 'w').write(s2)
patch('app/Models/ProductStock.php', '$touches',
      "    protected $fillable = ['product_id'",
      "    protected $touches = ['product'];\n\n    protected $fillable = ['product_id'")
patch('bootstrap/app.php', 'EnsureSellerApi',
      "            'shop.approved'",
      "            'seller' => \\App\\Http\\Middleware\\EnsureSellerApi::class,\n"
      "            'admin.api' => \\App\\Http\\Middleware\\EnsureAdminApi::class,\n"
      "            'shop.approved'")
PY

echo "4/5 Migraciones pendientes (no borra nada)"
php artisan migrate --force

echo "5/5 Comprobación"
php artisan route:clear >/dev/null 2>&1 || true
php artisan route:list --path=api/sync >/dev/null && echo "   OK: la ruta /api/sync/products existe."
echo
echo "Listo. Reinicia 'php artisan serve' si estaba abierto y vuelve a abrir la app."
echo "Pruebas de la API:  php artisan test tests/Feature/Api"
