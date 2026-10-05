<?php

namespace Tests\Feature\Api;

use App\Models\Order;
use App\Models\User;
use App\Notifications\OrderStatusUpdatedNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class OrderApiTest extends TestCase
{
    use ApiTestHelpers, RefreshDatabase;

    /** Pedido pagado con una línea de cada vendedor. */
    private function sharedOrder(User $buyer, User $sellerA, User $sellerB, string $payment = 'paid'): Order
    {
        $order = Order::create([
            'user_id' => $buyer->id, 'code' => 'ORD-'.uniqid(), 'status' => 'pagado', 'payment_status' => $payment,
            'delivery_status' => 'pending', 'subtotal' => 30, 'shipping_total' => 0, 'tax_amount' => 0, 'grand_total' => 30,
            'shipping_address' => $this->completeShippingAddress($buyer),
        ]);
        foreach ([[$sellerA, 10], [$sellerB, 20]] as [$seller, $price]) {
            $p = $this->makeProduct($seller, $price);
            $order->orderDetails()->create(['seller_id' => $seller->id, 'product_id' => $p->id,
                'product_name' => 'De '.$seller->id, 'price' => $price, 'quantity' => 1, 'payment_status' => $payment]);
        }

        return $order;
    }

    public function test_buyer_sees_all_lines_of_their_order(): void
    {
        $buyer = $this->makeCustomer();
        $order = $this->sharedOrder($buyer, $this->makeSeller(), $this->makeSeller());

        $this->as($buyer)->getJson("/api/orders/{$order->id}")
            ->assertOk()->assertJsonCount(2, 'items')->assertJsonPath('grand_total', 30);
    }

    /** Antes: un vendedor veía las líneas y el total de los demás vendedores del mismo pedido. */
    public function test_seller_only_sees_their_own_lines_and_their_own_total(): void
    {
        [$a, $b] = [$this->makeSeller(), $this->makeSeller()];
        $order = $this->sharedOrder($this->makeCustomer(), $a, $b);

        $this->as($a)->getJson("/api/orders/{$order->id}")
            ->assertOk()->assertJsonCount(1, 'items')
            ->assertJsonPath('items.0.seller_id', $a->id)
            ->assertJsonPath('grand_total', 10);

        $sync = $this->as($a)->getJson('/api/sync/orders')->assertOk()->json('changed');
        $this->assertCount(1, $sync[0]['items']);
    }

    /** Antes: /sync/orders entregaba al vendedor pedidos SIN pagar (carritos a medio pagar de otros clientes). */
    public function test_seller_does_not_receive_unpaid_orders_of_buyers(): void
    {
        $seller = $this->makeSeller();
        $this->sharedOrder($this->makeCustomer(), $seller, $this->makeSeller(), 'unpaid');

        $this->as($seller)->getJson('/api/sync/orders')->assertOk()->assertJsonCount(0, 'changed');
    }

    public function test_seller_flow_confirm_then_warehouse_notifies_the_buyer(): void
    {
        Notification::fake();
        $buyer = $this->makeCustomer();
        $seller = $this->makeSeller();
        $order = $this->sharedOrder($buyer, $seller, $this->makeSeller());

        $this->as($seller)->postJson("/api/seller/orders/{$order->id}/confirm")->assertOk()->assertJsonPath('delivery_status', 'confirmed');
        $this->as($seller)->postJson("/api/seller/orders/{$order->id}/confirm")->assertStatus(422);
        $this->as($seller)->postJson("/api/seller/orders/{$order->id}/send-to-warehouse")->assertOk()->assertJsonPath('delivery_status', 'warehouse');

        Notification::assertSentTo($buyer, OrderStatusUpdatedNotification::class, fn ($n) => true);
    }

    public function test_customer_cannot_use_seller_actions(): void
    {
        $buyer = $this->makeCustomer();
        $order = $this->sharedOrder($buyer, $this->makeSeller(), $this->makeSeller());

        $this->as($buyer)->postJson("/api/seller/orders/{$order->id}/confirm")->assertForbidden();
    }

    public function test_stranger_cannot_see_an_order(): void
    {
        $order = $this->sharedOrder($this->makeCustomer(), $this->makeSeller(), $this->makeSeller());

        $this->as($this->makeCustomer())->getJson("/api/orders/{$order->id}")->assertNotFound();
    }
}
