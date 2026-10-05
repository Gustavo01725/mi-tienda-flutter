<?php

namespace Tests\Feature\Api;

use App\Models\ProductStock;
use App\Models\User;
use App\Notifications\VerifyEmailNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class AuthAndSellerApiTest extends TestCase
{
    use ApiTestHelpers, RefreshDatabase;

    public function test_login_returns_a_token_and_logout_revokes_it(): void
    {
        $user = User::factory()->create(['password' => 'secret123', 'user_type' => 'customer']);

        $token = $this->postJson('/api/auth/login', ['email' => $user->email, 'password' => 'secret123'])
            ->assertOk()->assertJsonPath('user.user_type', 'customer')->json('token');

        $this->withToken($token)->getJson('/api/auth/me')->assertOk();
        $this->withToken($token)->postJson('/api/auth/logout')->assertOk();
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/auth/me')->assertUnauthorized();
    }

    public function test_wrong_password_and_banned_users_cannot_log_in(): void
    {
        $user = User::factory()->create(['password' => 'secret123', 'banned' => 1]);

        $this->postJson('/api/auth/login', ['email' => $user->email, 'password' => 'nope'])->assertStatus(422);
        $this->postJson('/api/auth/login', ['email' => $user->email, 'password' => 'secret123'])->assertStatus(422);
    }

    /** Antes: registrarse desde la app no mandaba el correo de verificación que manda la web. */
    public function test_register_creates_a_customer_and_sends_the_verification_email(): void
    {
        Notification::fake();

        $this->postJson('/api/auth/register', ['name' => 'Nuevo', 'email' => 'nuevo@example.com', 'password' => 'secret123', 'user_type' => 'admin'])
            ->assertCreated()->assertJsonPath('user.user_type', 'customer');

        Notification::assertSentTo(User::where('email', 'nuevo@example.com')->sole(), VerifyEmailNotification::class);
    }

    /** Antes: la API dejaba gestionar inventario a vendedores sin correo verificado (la web no). */
    public function test_unverified_seller_cannot_use_seller_endpoints(): void
    {
        $seller = $this->makeSeller();
        $seller->forceFill(['email_verified_at' => null, 'email_verified' => 0])->save();

        $this->as($seller)->getJson('/api/seller/products')->assertForbidden();
    }

    public function test_pending_shop_cannot_use_seller_endpoints(): void
    {
        $this->as($this->makePendingSeller())->getJson('/api/seller/products')->assertForbidden();
    }

    public function test_seller_cannot_edit_another_sellers_product(): void
    {
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 1]);

        $this->as($this->makeSeller())->putJson("/api/seller/products/{$product->id}", ['unit_price' => 1])->assertForbidden();
    }

    /** Antes: se aceptaba un descuento de 150 % y el precio quedaba negativo. */
    public function test_percent_discount_over_100_is_rejected(): void
    {
        $seller = $this->makeSeller();
        $product = $this->productWithStock($seller, ['M-negro' => 1]);

        $this->as($seller)->putJson("/api/seller/products/{$product->id}", ['discount' => 150])->assertStatus(422);
    }

    /** Antes: si una fila fallaba, las anteriores ya se habían guardado (actualización a medias). */
    public function test_stock_update_is_all_or_nothing(): void
    {
        $seller = $this->makeSeller();
        $product = $this->productWithStock($seller, ['M-negro' => 1]);
        $stock = $product->stocks->first();

        $this->as($seller)->putJson("/api/seller/products/{$product->id}/stocks", ['stocks' => [
            ['id' => $stock->id, 'qty' => 50],
            ['id' => 999999, 'qty' => 1],
        ]])->assertNotFound();

        $this->assertSame(1, (int) $stock->fresh()->qty);
    }

    public function test_stock_update_by_owner_is_visible_in_the_catalog(): void
    {
        $seller = $this->makeSeller();
        $product = $this->productWithStock($seller, ['M-negro' => 1]);
        $stock = $product->stocks->first();

        $this->as($seller)->putJson("/api/seller/products/{$product->id}/stocks", ['stocks' => [['id' => $stock->id, 'qty' => 7]]])
            ->assertOk()->assertJsonPath('total_stock', 7);
        $this->assertSame(7, (int) ProductStock::find($stock->id)->qty);
    }
}
