<?php

namespace Tests\Feature\Api;

use App\Models\Cart;
use App\Models\Product;
use App\Models\ProductStock;
use App\Models\User;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\BuildsCheckoutData;

/** Ayudantes de las pruebas de la API (reutiliza los de la web: BuildsCheckoutData). */
trait ApiTestHelpers
{
    use BuildsCheckoutData;

    protected function as(User $user): static
    {
        Sanctum::actingAs($user);

        return $this;
    }

    /** Producto publicado con una fila de stock por variante ('M-negro' => qty, o '' => qty sin variante). */
    protected function productWithStock(User $seller, array $stocks, float $price = 20.0, array $extra = []): Product
    {
        $product = $this->makeProduct($seller, $price);
        $product->update($extra + ['published' => 1, 'approved' => 1]);

        foreach ($stocks as $variant => $qty) {
            [$size, $color] = $variant === '' ? [null, null] : array_pad(explode('-', $variant, 2), 2, null);
            ProductStock::create([
                'product_id' => $product->id, 'size' => $size, 'color' => $color,
                'price' => $price, 'qty' => $qty,
            ]);
        }

        return $product->fresh('stocks');
    }

    protected function cartLine(User $user, Product $product, ?string $variation, int $qty, ?float $price = null): Cart
    {
        return Cart::create([
            'user_id' => $user->id, 'product_id' => $product->id, 'variation' => $variation,
            'quantity' => $qty, 'price' => $price ?? $product->unit_price, 'shipping_cost' => 0,
        ]);
    }
}
