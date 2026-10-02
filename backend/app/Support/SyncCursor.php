<?php

namespace App\Support;

use Illuminate\Support\Carbon;

/**
 * Convierte el cursor `since` que manda la app (ISO 8601 con "T" y zona) en un Carbon.
 * Pasar el string tal cual rompe la comparación en SQLite, que compara texto
 * ("2026-10-02 10:00:00" < "2026-10-02T09:00:00" por el espacio frente a la T).
 * Con Carbon, Eloquent lo formatea como la columna y funciona igual en SQLite, MySQL y Postgres.
 */
class SyncCursor
{
    public static function parse(?string $since): ?Carbon
    {
        if (! $since) {
            return null;
        }

        try {
            return Carbon::parse($since)->setTimezone(config('app.timezone'));
        } catch (\Throwable) {
            return null;
        }
    }
}
