<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Address;
use App\Models\Cart;
use App\Models\Order;
use App\Services\CheckoutService;
use App\Services\Payments\StripeService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Checkout sin sesión (la web guarda el pedido pendiente en session()).
 * Pago con Stripe PaymentSheet: la app recibe clientSecret y publishableKey;
 * el webhook de la web (payment_intent.succeeded) marca el pedido como pagado.
 * Kushki (Ecuador) no está expuesto en la API.
 */
class CheckoutController extends Controller
{
    private const SETTLING = ['processing', 'succeeded', 'requires_capture'];

    public function __construct(private CheckoutService $checkout, private StripeService $stripe) {}

    /** Crea (o reutiliza) el pedido pendiente a partir del carrito y devuelve el intent. */
    public function intent(Request $request)
    {
        $user = $request->user();
        $ship = $request->validate([
            'full_name' => 'required|string|max:255',
            'phone' => 'required|string|max:30',
            'email' => 'required|email|max:255',
            'address' => 'required|string|max:255',
            'city' => 'required|string|max:100',
            'state' => 'nullable|string|max:100',
            'country' => 'nullable|string|max:100',
            'postal_code' => 'nullable|string|max:20',
        ]);

        $items = $this->checkout->items($user);
        if ($items->isEmpty()) {
            return response()->json(['message' => 'Tu carrito está vacío.'], 422);
        }

        // Revalida stock: el carrito pudo quedar desfasado por ventas en la web.
        foreach ($items as $i) {
            $stock = $i->variation
                ? $i->product->stocks()->where('variant', $i->variation)->first()
                : $i->product->stocks()->first();
            if (! $stock || $stock->qty < $i->quantity) {
                return response()->json(['message' => "Sin stock suficiente de {$i->product->name}."], 422);
            }
        }

        Address::updateOrCreate(['user_id' => $user->id, 'is_default' => 1], $ship);

        $totals = $this->checkout->totals($items);

        $order = DB::transaction(function () use ($user, $items, $totals, $ship) {
            $order = Order::where('user_id', $user->id)->where('payment_status', 'unpaid')
                ->where('status', 'pendiente')->latest('id')->first();

            $fields = [
                'subtotal' => $totals['subtotal'], 'shipping_total' => $totals['shipping'],
                'tax_amount' => $totals['tax'], 'grand_total' => $totals['grand_total'],
                'shipping_address' => $ship,
            ];

            if ($order) {
                $order->update($fields);
                $order->orderDetails()->delete();
            } else {
                $order = Order::create($fields + [
                    'user_id' => $user->id,
                    'code' => 'ORD-'.date('Ymd').'-'.strtoupper(substr(uniqid(), -6)),
                    'status' => 'pendiente', 'payment_status' => 'unpaid', 'delivery_status' => 'pending',
                ]);
            }

            foreach ($items as $i) {
                $order->orderDetails()->create([
                    'seller_id' => $i->product->added_by, 'product_id' => $i->product_id,
                    'variation' => $i->variation, 'product_name' => $i->product->name,
                    'price' => $i->price, 'quantity' => $i->quantity, 'tax' => $i->tax ?? 0,
                    'shipping_cost' => $i->shipping_cost ?? 0, 'discount_on_product' => 0,
                    'delivery_status' => 'pending', 'payment_status' => 'unpaid',
                ]);
            }

            return $order;
        });

        $cents = (int) round($order->grand_total * 100);

        try {
            if ($order->payment_intent_id) {
                $intent = $this->stripe->retrieveIntent($order->payment_intent_id);
                if (in_array($intent->status, self::SETTLING, true)) {
                    return response()->json(['message' => 'Ya hay un pago en curso para este pedido.'], 409);
                }
                if (in_array($intent->status, ['requires_payment_method', 'requires_confirmation', 'requires_action'], true)) {
                    if ($intent->amount !== $cents) {
                        $intent = $this->stripe->updateIntent($intent->id, ['amount' => $cents]);
                    }

                    return $this->intentJson($order, $intent->client_secret);
                }
            }
        } catch (Throwable) {
            // intent inexistente en esta cuenta: se crea uno nuevo
        }

        try {
            $intent = $this->stripe->createIntent($cents, 'usd', ['order_id' => (string) $order->id]);
        } catch (Throwable) {
            return response()->json(['message' => 'No se pudo iniciar el pago. Intenta de nuevo.'], 422);
        }
        $order->update(['payment_intent_id' => $intent->id]);

        return $this->intentJson($order, $intent->client_secret);
    }

    /**
     * La app llama aquí tras el PaymentSheet. Verifica el intent con Stripe (igual que
     * success() en la web) por si el webhook aún no llegó. Idempotente.
     */
    public function confirm(Request $request, $id)
    {
        $order = Order::where('user_id', $request->user()->id)->findOrFail($id);

        if (! $order->isPaid() && $order->payment_intent_id) {
            try {
                $intent = $this->stripe->retrieveIntent($order->payment_intent_id);
                if ($intent->status === 'succeeded' && (string) ($intent->metadata['order_id'] ?? '') === (string) $order->id) {
                    $order->markPaid('stripe', $intent->id);
                    Cart::where('user_id', $order->user_id)->delete();
                }
            } catch (Throwable) {
                // lo resolverá el webhook
            }
        }

        return response()->json(['paid' => $order->fresh()->isPaid(), 'order_id' => $order->id]);
    }

    private function intentJson(Order $order, ?string $secret)
    {
        return response()->json([
            'client_secret' => $secret,
            'publishable_key' => config('services.stripe.key'),
            'order_id' => $order->id,
            'code' => $order->code,
            'amount' => (float) $order->grand_total,
        ]);
    }
}
