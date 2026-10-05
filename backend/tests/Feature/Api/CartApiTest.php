<?php

namespace Tests\Feature\Api;

use App\Models\Cart;
use App\Models\ProductStock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CartApiTest extends TestCase
{
    use ApiTestHelpers, RefreshDatabase;

    public function test_cart_requires_authentication(): void
    {
        $this->getJson('/api/cart')->assertUnauthorized();
    }

    public function test_add_applies_discount_and_returns_totals(): void
    {
        $customer = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 5], 20.0, ['discount' => 10, 'shipping_cost' => 2]);

        $this->as($customer)->postJson('/api/cart', ['product_id' => $product->id, 'variation' => 'M-negro', 'quantity' => 2])
            ->assertOk()
            ->assertJsonPath('count', 2)
            ->assertJsonPath('subtotal', 36)
            ->assertJsonPath('shipping', 2)
            ->assertJsonPath('total', 38)
            ->assertJsonPath('items.0.variation', 'M-negro');
    }

    public function test_add_requires_a_variant_for_variant_products(): void
    {
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 5]);

        $this->as($this->makeCustomer())->postJson('/api/cart', ['product_id' => $product->id])
            ->assertStatus(422);
    }

    public function test_add_rejects_more_than_stock(): void
    {
        $product = $this->productWithStock($this->makeSeller(), ['L-negro' => 2]);

        $this->as($this->makeCustomer())->postJson('/api/cart', ['product_id' => $product->id, 'variation' => 'L-negro', 'quantity' => 9])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Solo hay 2 unidades en stock');
    }

    public function test_add_rejects_unpublished_products(): void
    {
        $product = $this->productWithStock($this->makeSeller(), ['' => 5], 10, ['published' => 0]);

        $this->as($this->makeCustomer())->postJson('/api/cart', ['product_id' => $product->id])->assertNotFound();
    }

    /** Antes: con el stock agotado en la web, PUT dejaba la línea con cantidad 0. */
    public function test_update_does_not_leave_a_zero_quantity_line_when_stock_ran_out(): void
    {
        $customer = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 3]);
        $line = $this->cartLine($customer, $product, 'M-negro', 1);
        ProductStock::where('product_id', $product->id)->update(['qty' => 0]);

        $this->as($customer)->putJson("/api/cart/{$line->id}", ['quantity' => 2])->assertStatus(422);

        $this->assertSame(1, $line->fresh()->quantity);
    }

    public function test_update_caps_quantity_to_stock(): void
    {
        $customer = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 3]);
        $line = $this->cartLine($customer, $product, 'M-negro', 1);

        $this->as($customer)->putJson("/api/cart/{$line->id}", ['quantity' => 10])->assertOk();

        $this->assertSame(3, $line->fresh()->quantity);
    }

    public function test_cannot_touch_someone_elses_cart_line(): void
    {
        $owner = $this->makeCustomer();
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 3]);
        $line = $this->cartLine($owner, $product, 'M-negro', 1);

        $this->as($this->makeCustomer())->deleteJson("/api/cart/{$line->id}")->assertNotFound();
        $this->assertNotNull(Cart::find($line->id));
    }
}
