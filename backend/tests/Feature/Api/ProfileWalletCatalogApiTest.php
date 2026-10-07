<?php

namespace Tests\Feature\Api;

use App\Models\User;
use App\Models\WalletRecharge;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ProfileWalletCatalogApiTest extends TestCase
{
    use ApiTestHelpers, RefreshDatabase;

    public function test_profile_update_changes_name_email_and_phone(): void
    {
        $user = $this->makeCustomer();

        $this->as($user)->putJson('/api/profile', ['name' => 'Ana', 'email' => 'ana@example.com', 'phone' => '0999'])
            ->assertOk()->assertJsonPath('name', 'Ana')->assertJsonPath('email', 'ana@example.com');
        $this->assertSame('0999', $user->fresh()->phone);
    }

    public function test_profile_email_must_be_unique(): void
    {
        $other = $this->makeCustomer();

        $this->as($this->makeCustomer())->putJson('/api/profile', ['name' => 'X', 'email' => $other->email])
            ->assertStatus(422)->assertJsonPath('errors.email.0', 'Este correo ya está en uso.');
    }

    public function test_password_change_requires_the_current_password(): void
    {
        $user = User::factory()->create(['password' => 'secret123']);

        $this->as($user)->putJson('/api/profile/password', [
            'current_password' => 'wrong', 'password' => 'nuevaClave1', 'password_confirmation' => 'nuevaClave1',
        ])->assertStatus(422);

        $this->as($user)->putJson('/api/profile/password', [
            'current_password' => 'secret123', 'password' => 'nuevaClave1', 'password_confirmation' => 'nuevaClave1',
        ])->assertOk();
        $this->assertTrue(Hash::check('nuevaClave1', $user->fresh()->password));
    }

    public function test_wallet_returns_balance_and_history(): void
    {
        $user = $this->makeCustomer();
        $user->forceFill(['balance' => 12.5])->save();
        WalletRecharge::create(['user_id' => $user->id, 'amount' => 10, 'approval' => 0]);

        $this->as($user)->getJson('/api/wallet')->assertOk()
            ->assertJsonPath('balance', 12.5)
            ->assertJsonPath('recharges.0.status', 'pending')
            ->assertJsonCount(0, 'withdrawals');
    }

    public function test_categories_include_active_product_counts(): void
    {
        $seller = $this->makeSeller();
        $this->productWithStock($seller, ['' => 1]);
        $this->productWithStock($seller, ['' => 1], 5, ['published' => 0]);

        $this->getJson('/api/categories')->assertOk()
            ->assertJsonPath('0.name', 'General')
            ->assertJsonPath('0.products_count', 1);
    }

    public function test_stocks_expose_the_web_color_palette(): void
    {
        $this->productWithStock($this->makeSeller(), ['M-negro' => 2]);

        $stock = $this->getJson('/api/sync/products')->json('changed.0.stocks.0');
        $this->assertSame('M', $stock['size']);
        $this->assertSame(config('variants.colors.negro.hex'), $stock['color_hex']);
        $this->assertNotEmpty($stock['color_label']);
    }

    public function test_sizes_come_in_the_web_order_not_the_stock_row_order(): void
    {
        $seller = $this->makeSeller();
        $product = $this->productWithStock($seller, ['L-negro' => 1, 'M-negro' => 1]); // L creada antes que M
        $product->update(['variant_type' => 'apparel']);

        $p = $this->getJson('/api/sync/products')->json('changed.0');
        $this->assertSame(['M', 'L'], $p['sizes']);
        $this->assertSame(['negro'], $p['colors']);
    }
}
