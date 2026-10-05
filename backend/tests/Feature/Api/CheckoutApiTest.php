<?php

namespace Tests\Feature\Api;

use App\Models\Cart;
use App\Models\Order;
use App\Models\ProductStock;
use App\Services\Payments\StripeService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Stripe\PaymentIntent;
use Tests\TestCase;

class CheckoutApiTest extends TestCase
{
    use ApiTestHelpers, RefreshDatabase;

    private function shipping($customer): array
    {
        return $this->completeShippingAddress($customer);
    }

    public function test_intent_creates_the_order_from_the_cart_and_returns_the_client_secret(): void
    {
        $customer = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 5], 25.0);
        $this->cartLine($customer, $product, 'M-negro', 2, 25.0);

        $this->mock(StripeService::class, fn ($m) => $m->shouldReceive('createIntent')->once()
            ->withArgs(fn (int $cents) => $cents === 5000)
            ->andReturn(PaymentIntent::constructFrom(['id' => 'pi_1', 'client_secret' => 'cs_1'])));

        $this->as($customer)->postJson('/api/checkout/intent', $this->shipping($customer))
            ->assertOk()
            ->assertJsonPath('client_secret', 'cs_1');

        $order = Order::sole();
        $this->assertSame('pi_1', $order->payment_intent_id);
        $this->assertSame('unpaid', $order->payment_status);
        $this->assertSame(2, (int) $order->orderDetails()->sole()->quantity);
    }

    public function test_intent_rejects_when_stock_is_no_longer_enough(): void
    {
        $customer = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 1]);
        $this->cartLine($customer, $product, 'M-negro', 3);

        $this->mock(StripeService::class, fn ($m) => $m->shouldNotReceive('createIntent'));

        $this->as($customer)->postJson('/api/checkout/intent', $this->shipping($customer))->assertStatus(422);
        $this->assertSame(0, Order::count());
    }

    /**
     * Antes: el pedido se reescribía con el carrito actual ANTES de mirar el intent. Si el pago
     * ya estaba en curso, el pedido cobrado terminaba con líneas distintas a las pagadas.
     */
    public function test_intent_does_not_rewrite_an_order_whose_payment_is_in_flight(): void
    {
        $customer = $this->makeCustomer();
        $seller = $this->makeSeller();
        $order = $this->makePendingOrder($customer, $seller, 80.00);
        $order->update(['payment_intent_id' => 'pi_busy']);
        // El comprador añade otra cosa mientras el primer pago se procesa.
        $other = $this->productWithStock($seller, ['M-negro' => 5], 10.0);
        $this->cartLine($customer, $other, 'M-negro', 1, 10.0);
        ProductStock::create(['product_id' => $order->orderDetails()->first()->product_id, 'price' => 80, 'qty' => 5]);

        $this->mock(StripeService::class, function ($m) {
            $m->shouldReceive('retrieveIntent')->andReturn(PaymentIntent::constructFrom(['id' => 'pi_busy', 'status' => 'processing', 'amount' => 8000]));
            $m->shouldNotReceive('createIntent');
            $m->shouldNotReceive('updateIntent');
        });

        $this->as($customer)->postJson('/api/checkout/intent', $this->shipping($customer))->assertStatus(409);

        $order->refresh();
        $this->assertEquals(80.00, (float) $order->grand_total);
        $this->assertSame(1, $order->orderDetails()->count());
    }

    public function test_confirm_payment_marks_the_order_paid_and_empties_the_cart(): void
    {
        $customer = $this->makeCustomer();
        $order = $this->makePendingOrder($customer, $this->makeSeller(), 30.00);
        $order->update(['payment_intent_id' => 'pi_ok']);

        $this->mock(StripeService::class, fn ($m) => $m->shouldReceive('retrieveIntent')->andReturn(
            PaymentIntent::constructFrom(['id' => 'pi_ok', 'status' => 'succeeded', 'metadata' => ['order_id' => (string) $order->id]])));

        $this->as($customer)->postJson("/api/orders/{$order->id}/confirm-payment")
            ->assertOk()->assertJsonPath('paid', true);

        $this->assertTrue($order->fresh()->isPaid());
        $this->assertSame(0, Cart::where('user_id', $customer->id)->count());
    }

    public function test_confirm_payment_of_another_users_order_is_not_found(): void
    {
        $order = $this->makePendingOrder($this->makeCustomer(), $this->makeSeller());

        $this->as($this->makeCustomer())->postJson("/api/orders/{$order->id}/confirm-payment")->assertNotFound();
    }

    // ── Kushki ──────────────────────────────────────────────────

    private function kushkiPayload($customer): array
    {
        return $this->shipping($customer) + [
            'token' => 'tok_test', 'document_type' => 'CC', 'document_number' => '1712345678',
            'first_name' => 'Ana', 'last_name' => 'Pérez',
        ];
    }

    public function test_kushki_charge_marks_the_order_paid(): void
    {
        config(['services.kushki.private_id' => 'priv']);
        Http::fake(['*/card/v1/charges' => Http::response(['ticketNumber' => 'T-1'])]);
        $customer = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['' => 5], 50.0);
        $this->cartLine($customer, $product, null, 1, 50.0);

        $this->as($customer)->postJson('/api/checkout/kushki', $this->kushkiPayload($customer))
            ->assertOk()->assertJsonPath('paid', true);

        $order = Order::sole();
        $this->assertTrue($order->isPaid());
        $this->assertSame('T-1', $order->payment_reference);
        $this->assertSame(4, (int) ProductStock::where('product_id', $product->id)->value('qty'));
        Http::assertSent(fn ($r) => $r['token'] === 'tok_test' && $r['amount']['subtotalIva'] + $r['amount']['iva'] == 50.0);
    }

    /** Antes: una caída de red con Kushki devolvía un 500 sin JSON y la app no sabía si se cobró. */
    public function test_kushki_network_failure_returns_a_clear_error_and_leaves_the_order_unpaid(): void
    {
        Http::fake(fn () => throw new ConnectionException('timeout'));
        $customer = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['' => 5], 50.0);
        $this->cartLine($customer, $product, null, 1, 50.0);

        $this->as($customer)->postJson('/api/checkout/kushki', $this->kushkiPayload($customer))
            ->assertStatus(502)->assertJsonStructure(['message']);

        $this->assertFalse(Order::sole()->isPaid());
    }

    /** Antes: si había un intent de Stripe en curso para el mismo pedido, Kushki cobraba igual (doble cobro). */
    public function test_kushki_refuses_while_a_stripe_payment_is_in_flight_for_the_same_order(): void
    {
        Http::fake();
        $customer = $this->makeCustomer();
        $order = $this->makePendingOrder($customer, $this->makeSeller(), 40.00);
        $order->update(['payment_intent_id' => 'pi_busy']);
        ProductStock::create(['product_id' => $order->orderDetails()->first()->product_id, 'price' => 40, 'qty' => 5]);

        $this->mock(StripeService::class, fn ($m) => $m->shouldReceive('retrieveIntent')->andReturn(
            PaymentIntent::constructFrom(['id' => 'pi_busy', 'status' => 'processing', 'amount' => 4000])));

        $this->as($customer)->postJson('/api/checkout/kushki', $this->kushkiPayload($customer))->assertStatus(409);

        Http::assertNothingSent();
        $this->assertFalse($order->fresh()->isPaid());
    }

    public function test_kushki_rejected_card_returns_the_gateway_message(): void
    {
        Http::fake(['*' => Http::response(['message' => 'Tarjeta no válida'], 400)]);
        $customer = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['' => 5], 50.0);
        $this->cartLine($customer, $product, null, 1, 50.0);

        $this->as($customer)->postJson('/api/checkout/kushki', $this->kushkiPayload($customer))
            ->assertStatus(422)->assertJsonPath('message', 'Tarjeta no válida');
    }
}
