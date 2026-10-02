<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\User;
use App\Notifications\OrderArrivedWarehouseNotification;
use App\Notifications\OrderStatusUpdatedNotification;
use App\Support\SyncCursor;
use Illuminate\Http\Request;

/** Pedidos del cliente y gestión de pedidos del vendedor (mismas transiciones que la web). */
class OrderController extends Controller
{
    public function index(Request $request)
    {
        $orders = Order::with('orderDetails.product')->where('user_id', $request->user()->id)->latest('id')->get();

        return response()->json($orders->map(fn ($o) => self::json($o))->values());
    }

    public function show(Request $request, $id)
    {
        $user = $request->user();
        $order = Order::with('orderDetails.product')->where(function ($q) use ($user) {
            $q->where('user_id', $user->id)
                ->orWhereHas('orderDetails', fn ($d) => $d->where('seller_id', $user->id));
        })->findOrFail($id);

        return response()->json(self::json($order, $user->id));
    }

    /** Cambios desde `since`: pedidos propios y, si vende, los que contienen sus productos. */
    public function sync(Request $request)
    {
        $now = now();
        $user = $request->user();

        $q = Order::with('orderDetails.product')->where(function ($w) use ($user) {
            $w->where('user_id', $user->id)
                ->orWhereHas('orderDetails', fn ($d) => $d->where('seller_id', $user->id));
        });
        if ($since = SyncCursor::parse($request->query('since'))) {
            $q->where('updated_at', '>=', $since);
        }

        return response()->json([
            'server_time' => $now->toIso8601String(),
            'changed' => $q->get()->map(fn ($o) => self::json($o, $user->id))->values(),
        ]);
    }

    // ── Vendedor ────────────────────────────────────────────────

    public function sellerIndex(Request $request)
    {
        $sid = $request->user()->id;
        $orders = Order::with(['orderDetails' => fn ($q) => $q->where('seller_id', $sid)->with('product')])
            ->whereHas('orderDetails', fn ($q) => $q->where('seller_id', $sid))
            ->where('payment_status', 'paid')->latest('id')->get();

        return response()->json($orders->map(fn ($o) => self::json($o, $sid))->values());
    }

    public function confirm(Request $request, $id)
    {
        $sid = $request->user()->id;
        $order = Order::whereHas('orderDetails', fn ($q) => $q->where('seller_id', $sid))->findOrFail($id);

        if ($order->payment_status !== 'paid') {
            return response()->json(['message' => 'El pedido aún no tiene el pago confirmado.'], 422);
        }
        if ($order->delivery_status !== 'pending') {
            return response()->json(['message' => 'Solo se pueden confirmar pedidos en estado "Pendiente".'], 422);
        }

        $order->update(['delivery_status' => 'confirmed', 'confirmed_at' => now()]);
        $order->orderDetails()->where('seller_id', $sid)->update(['delivery_status' => 'confirmed']);
        $order->user?->notify(new OrderStatusUpdatedNotification($order, 'confirmed'));

        return response()->json(self::json($order->fresh('orderDetails.product'), $sid));
    }

    public function sendToWarehouse(Request $request, $id)
    {
        $user = $request->user();
        $order = Order::whereHas('orderDetails', fn ($q) => $q->where('seller_id', $user->id))->findOrFail($id);

        if ($order->delivery_status !== 'confirmed') {
            return response()->json(['message' => 'El pedido debe estar "Confirmado" para enviarlo al almacén.'], 422);
        }

        if (! $order->hasCompleteShippingInfo() && $order->user) {
            $order->update(['shipping_address' => array_merge(
                $order->user->shippingSnapshot(),
                array_filter($order->shippingInfo(), fn ($v) => trim((string) $v) !== ''),
            )]);
        }
        if (! $order->hasCompleteShippingInfo()) {
            return response()->json(['message' => 'Faltan datos de envío del cliente.'], 422);
        }

        $order->update(['delivery_status' => 'warehouse', 'warehouse_at' => now()]);
        $order->orderDetails()->where('seller_id', $user->id)->update(['delivery_status' => 'warehouse']);

        User::where('user_type', 'admin')->get()
            ->each(fn ($a) => $a->notify(new OrderArrivedWarehouseNotification($order, $user->name)));
        $order->user?->notify(new OrderStatusUpdatedNotification($order, 'warehouse'));

        return response()->json(self::json($order->fresh('orderDetails.product'), $user->id));
    }

    public static function json(Order $o, ?int $viewerId = null): array
    {
        return [
            'id' => $o->id,
            'code' => $o->code,
            'user_id' => $o->user_id,
            'status' => $o->status,
            'payment_status' => $o->payment_status,
            'delivery_status' => $o->delivery_status,
            'subtotal' => (float) $o->subtotal,
            'shipping_total' => (float) $o->shipping_total,
            'tax_amount' => (float) $o->tax_amount,
            'grand_total' => (float) $o->grand_total,
            'shipping_address' => $o->shippingInfo(),
            'created_at' => $o->created_at?->toIso8601String(),
            'updated_at' => $o->updated_at?->toIso8601String(),
            'items' => $o->orderDetails->map(fn ($d) => [
                'id' => $d->id,
                'product_id' => $d->product_id,
                'name' => $d->product_name,
                'thumbnail' => uploaded_asset($d->product?->thumbnail),
                'variant_label' => $d->variant_label,
                'price' => (float) $d->price,
                'quantity' => (int) $d->quantity,
                'seller_id' => $d->seller_id,
            ])->values(),
        ];
    }
}
