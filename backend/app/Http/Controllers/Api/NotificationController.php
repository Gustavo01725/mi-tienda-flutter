<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\SyncCursor;
use Illuminate\Http\Request;

/**
 * Avisos del usuario: la tabla `notifications` de Laravel, la misma que alimenta los
 * banners de la web (cambios de estado de pedidos, nuevas ventas, tienda aprobada,
 * liquidaciones). Todas las notificaciones existentes guardan su texto en data.message.
 *
 * Listar NO marca como leído: la web usa "leído" para mostrar sus banners una sola vez,
 * así que solo se marca cuando el usuario lo pide en la app.
 */
class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $q = $request->user()->notifications()->latest();

        if ($since = SyncCursor::parse($request->query('since'))) {
            $q->where('created_at', '>=', $since);
        }

        return response()->json([
            'server_time' => SyncCursor::next(),
            'unread_count' => $request->user()->unreadNotifications()->count(),
            'data' => $q->limit(50)->get()->map(fn ($n) => [
                'id' => $n->id,
                'message' => $n->data['message'] ?? '',
                'order_id' => $n->data['order_id'] ?? null,
                'type' => class_basename($n->type),
                'read' => $n->read_at !== null,
                'created_at' => $n->created_at->toIso8601String(),
            ])->values(),
        ]);
    }

    public function markRead(Request $request, string $id)
    {
        $request->user()->notifications()->whereKey($id)->update(['read_at' => now()]);

        return response()->json(['ok' => true]);
    }

    public function markAllRead(Request $request)
    {
        $request->user()->unreadNotifications()->update(['read_at' => now()]);

        return response()->json(['ok' => true]);
    }
}
