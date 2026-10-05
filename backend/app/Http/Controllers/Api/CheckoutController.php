<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Address;
use App\Models\Cart;
use App\Models\Order;
use App\Services\CheckoutService;
use App\Services\GeolocationService;
use App\Services\Payments\StripeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Stripe\StripeClient;
use Throwable;

/**
 * Checkout sin sesión (la web guarda el pedido pendiente en session()).
 * Pago con Stripe PaymentSheet: la app recibe clientSecret y publishableKey;
 * el webhook de la web (payment_intent.succeeded) marca el pedido como pagado.
 * Kushki (Ecuador): ver kushki().
 */
class CheckoutController extends Controller
{
    /** Estados en los que el dinero ya está comprometido: el pedido no se toca ni se cobra de nuevo. */
    private const SETTLING = ['processing', 'succeeded', 'requires_capture'];

    /** Estados en los que el intent todavía admite cambiar el monto y volver a cobrarse. */
    private const REUSABLE = ['requires_payment_method', 'requires_confirmation', 'requires_action'];

    public function __construct(private CheckoutService $checkout, private StripeService $stripe, private GeolocationService $geo) {}

    /**
     * Pasarela que corresponde al comprador (Ecuador → Kushki, resto → Stripe), igual que la web, y
     * sus datos de envío guardados para rellenar el formulario (CheckoutController::index de la web).
     */
    public function gateway(Request $request)
    {
        return response()->json([
            'gateway' => $this->geo->gatewayFor($request),
            'shipping' => $request->user()->shippingSnapshot(),
            'kushki' => [
                'public_id' => config('services.kushki.public_id'),
                'env' => config('services.kushki.env'),
            ],
        ]);
    }

    /**
     * Valida envío y carrito, revalida stock y deja el pedido pendiente listo para cobrar.
     * Devuelve el Order, o una respuesta JSON de error.
     */
    private function prepare(Request $request, array $extraRules = []): Order|JsonResponse
    {
        $user = $request->user();
        $ship = $request->validate($extraRules + [
            'full_name' => 'required|string|max:255',
            'phone' => 'required|string|max:30',
            'email' => 'required|email|max:255',
            'address' => 'required|string|max:255',
            'city' => 'required|string|max:100',
            'state' => 'nullable|string|max:100',
            'country' => 'nullable|string|max:100',
            'postal_code' => 'nullable|string|max:20',
        ]);
        $ship = Arr::only($ship, ['full_name', 'phone', 'email', 'address', 'city', 'state', 'country', 'postal_code']);

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
            $order = $this->pendingOrder($user->id);

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

        return $order;
    }

    /** Crea (o reutiliza) el pedido pendiente a partir del carrito y devuelve el intent de Stripe. */
    public function intent(Request $request)
    {
        return $this->exclusive($request, function () use ($request) {
            // El intent se mira ANTES de reescribir el pedido: si el pago ya está en curso, el pedido
            // tiene que quedar con las líneas que se están cobrando.
            [$intent, $busy] = $this->currentIntent($request);
            if ($busy) {
                return $busy;
            }

            $order = $this->prepare($request);
            if ($order instanceof JsonResponse) {
                return $order;
            }

            $cents = (int) round($order->grand_total * 100);

            if ($intent && in_array($intent->status, self::REUSABLE, true)) {
                try {
                    if ($intent->amount !== $cents) {
                        $intent = $this->stripe->updateIntent($intent->id, ['amount' => $cents]);
                    }

                    return $this->intentJson($order, $intent->client_secret);
                } catch (Throwable $e) {
                    Log::warning('Stripe: no se pudo actualizar el intent (api)', ['order_id' => $order->id, 'error' => $e->getMessage()]);
                }
            }

            try {
                $intent = $this->stripe->createIntent($cents, 'usd', ['order_id' => (string) $order->id]);
            } catch (Throwable $e) {
                Log::error('Stripe createIntent failed (api)', ['order_id' => $order->id, 'error' => $e->getMessage()]);

                return response()->json(['message' => 'No se pudo iniciar el pago. Intenta de nuevo.'], 422);
            }
            $order->update(['payment_intent_id' => $intent->id]);

            return $this->intentJson($order, $intent->client_secret);
        });
    }

    /**
     * Cobro con Kushki. La app tokeniza la tarjeta directamente con Kushki (los datos de la
     * tarjeta nunca pasan por este servidor) y envía solo el token. El cobro es el mismo que
     * hace KushkiController::charge en la web.
     */
    public function kushki(Request $request)
    {
        return $this->exclusive($request, function () use ($request) {
            // Si el mismo pedido tiene un pago de Stripe en curso, cobrar por Kushki sería un doble cobro.
            [$intent, $busy] = $this->currentIntent($request);
            if ($busy) {
                return $busy;
            }

            $order = $this->prepare($request, [
                'token' => 'required|string',
                'document_type' => 'required|in:CC,RUC,PP',
                'document_number' => 'required|string|max:20',
                'first_name' => 'required|string|max:100',
                'last_name' => 'required|string|max:100',
            ]);
            if ($order instanceof JsonResponse) {
                return $order;
            }

            // Un intent de Stripe abierto (sin pagar) se cancela: si no, podría cobrarse más tarde
            // además de este cobro de Kushki.
            if ($intent && in_array($intent->status, self::REUSABLE, true)) {
                $this->cancelStripeIntent($intent->id);
                $order->update(['payment_intent_id' => null]);
            }

            $total = (float) $order->grand_total;
            $iva = config('services.kushki.iva_rate', config('app.ec_iva_rate', 0.15));
            $base = round($total / (1 + $iva), 2);

            try {
                $response = Http::timeout(30)->withHeaders([
                    'Private-Merchant-Id' => config('services.kushki.private_id'),
                    'Content-Type' => 'application/json',
                ])->post($this->kushkiUrl().'/card/v1/charges', [
                    'token' => $request->token,
                    'amount' => [
                        'subtotalIva' => $base, 'subtotalIva0' => 0, 'ice' => 0,
                        'iva' => round($total - $base, 2), 'currency' => 'USD',
                    ],
                    'metadata' => ['order_id' => (string) $order->id],
                    'contactDetails' => [
                        'documentType' => $request->document_type,
                        'documentNumber' => $request->document_number,
                        'email' => $request->email,
                        'firstName' => $request->first_name,
                        'lastName' => $request->last_name,
                    ],
                ]);
            } catch (ConnectionException $e) {
                // No se sabe si Kushki llegó a cobrar: el webhook de Kushki de la web marcará el pedido si
                // lo hizo. El pedido queda sin pagar y la app avisa de revisar "Mis pedidos" antes de reintentar.
                Log::error('Kushki charge sin respuesta (api)', ['order_id' => $order->id, 'error' => $e->getMessage()]);

                return response()->json([
                    'message' => 'No hubo respuesta de Kushki. Revisa "Mis pedidos" en unos minutos antes de volver a pagar.',
                    'order_id' => $order->id,
                ], 502);
            }

            if ($response->successful()) {
                $order->markPaid('kushki', $response->json('ticketNumber') ?? '');
                Cart::where('user_id', $order->user_id)->delete();

                return response()->json(['paid' => true, 'order_id' => $order->id, 'code' => $order->code]);
            }

            Log::error('Kushki charge failed (api)', ['order_id' => $order->id, 'response' => $response->json()]);

            return response()->json(['message' => $response->json('message') ?? 'El pago fue rechazado'], 422);
        });
    }

    /**
     * Intent de Stripe del pedido pendiente del usuario, y una respuesta 409 si ese pago ya está
     * en curso o cobrado (en ese caso el pedido no se debe tocar).
     *
     * @return array{0: ?\Stripe\PaymentIntent, 1: ?JsonResponse}
     */
    private function currentIntent(Request $request): array
    {
        $order = $this->pendingOrder($request->user()->id);
        if (! $order?->payment_intent_id) {
            return [null, null];
        }

        try {
            $intent = $this->stripe->retrieveIntent($order->payment_intent_id);
        } catch (Throwable) {
            return [null, null]; // intent inexistente en esta cuenta (p. ej. claves de test → live)
        }

        if (in_array($intent->status, self::SETTLING, true)) {
            return [$intent, response()->json([
                'message' => 'Ya hay un pago en curso para este pedido. Espera unos segundos y revisa "Mis pedidos".',
                'order_id' => $order->id,
            ], 409)];
        }

        return [$intent, null];
    }

    private function pendingOrder(int $userId): ?Order
    {
        return Order::where('user_id', $userId)->where('payment_status', 'unpaid')
            ->where('status', 'pendiente')->latest('id')->first();
    }

    /** Un solo checkout a la vez por usuario: un doble toque no puede crear dos cobros. */
    private function exclusive(Request $request, callable $callback)
    {
        $lock = Cache::lock('api-checkout:'.$request->user()->id, 60);

        if (! $lock->get()) {
            return response()->json(['message' => 'Ya hay un pago en curso. Espera unos segundos.'], 409);
        }

        try {
            return $callback();
        } finally {
            $lock->release();
        }
    }

    private function cancelStripeIntent(string $id): void
    {
        if (! config('services.stripe.secret')) {
            return;
        }

        try {
            (new StripeClient(config('services.stripe.secret')))->paymentIntents->cancel($id);
        } catch (Throwable $e) {
            Log::warning('Stripe: no se pudo cancelar el intent al pagar con Kushki', ['intent' => $id, 'error' => $e->getMessage()]);
        }
    }

    private function kushkiUrl(): string
    {
        return config('services.kushki.env') === 'production'
            ? 'https://api.kushkipagos.com'
            : 'https://api-uat.kushkipagos.com';
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
