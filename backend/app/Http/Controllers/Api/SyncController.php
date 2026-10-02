<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductPresenter;
use App\Models\Product;
use App\Models\User;
use Illuminate\Http\Request;

/**
 * Sincronización incremental por cursor `updated_at`.
 *
 * La app guarda `server_time` de la última respuesta y lo manda como `since`.
 * Devuelve solo lo cambiado y la lista completa de ids vigentes, de modo que la
 * app también detecta productos borrados o despublicados en la web.
 * (Para push real en lugar de polling, ver backend/README.md → Reverb.)
 */
class SyncController extends Controller
{
    public function products(Request $request)
    {
        $now = now();
        $since = $request->query('since');

        $q = Product::active()->with(['stocks', 'category', 'brand']);
        if ($since) {
            $q->where('updated_at', '>', $since);
        }

        return response()->json([
            'server_time' => $now->toIso8601String(),
            'changed' => $q->get()->map(fn ($p) => ProductPresenter::make($p))->values(),
            'active_ids' => Product::active()->pluck('id'),
        ]);
    }

    public function users(Request $request)
    {
        $now = now();
        $q = User::query();
        if ($since = $request->query('since')) {
            $q->where('updated_at', '>', $since);
        }

        return response()->json([
            'server_time' => $now->toIso8601String(),
            'changed' => $q->get()->map(fn ($u) => AuthController::userJson($u))->values(),
            'all_ids' => User::pluck('id'),
        ]);
    }
}
