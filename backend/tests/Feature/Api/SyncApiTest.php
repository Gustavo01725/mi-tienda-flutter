<?php

namespace Tests\Feature\Api;

use App\Models\ProductStock;
use App\Notifications\SellerNewOrderNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class SyncApiTest extends TestCase
{
    use ApiTestHelpers, RefreshDatabase;

    public function test_full_sync_returns_active_products_with_variant_prices(): void
    {
        $product = $this->productWithStock($this->makeSeller(), ['M-negro' => 5], 20.0, ['discount' => 10]);
        $this->productWithStock($this->makeSeller(), ['' => 1], 5.0, ['published' => 0]);

        $r = $this->getJson('/api/sync/products')->assertOk();
        $r->assertJsonCount(1, 'changed')
            ->assertJsonPath('active_ids', [$product->id])
            ->assertJsonPath('changed.0.price', 18)
            ->assertJsonPath('changed.0.stocks.0.final_price', 18);
    }

    /** El cursor que manda la app (ISO 8601 con zona) debe funcionar también en SQLite. */
    public function test_incremental_sync_returns_only_products_changed_since_the_cursor(): void
    {
        Carbon::setTestNow('2026-10-05 10:00:00');
        $old = $this->productWithStock($this->makeSeller(), ['' => 1]);
        $changed = $this->productWithStock($this->makeSeller(), ['' => 1]);

        Carbon::setTestNow('2026-10-05 10:10:00');
        ProductStock::where('product_id', $changed->id)->first()->update(['qty' => 9]); // toca products.updated_at

        $r = $this->getJson('/api/sync/products?since='.urlencode('2026-10-05T10:05:00+00:00'))->assertOk();
        $this->assertSame([$changed->id], array_column($r->json('changed'), 'id'));
        $this->assertSame(9, $r->json('changed.0.total_stock'));
        $this->assertContains($old->id, $r->json('active_ids'));
    }

    /**
     * El cursor devuelto deja un margen hacia atrás: una escritura con updated_at justo antes de la
     * consulta pero confirmada después no se pierde para siempre (la app deduplica por id).
     */
    public function test_cursor_leaves_a_safety_margin(): void
    {
        Carbon::setTestNow('2026-10-05 10:00:30');

        $cursor = Carbon::parse($this->getJson('/api/sync/products')->json('server_time'));
        $this->assertTrue($cursor->lt(Carbon::parse('2026-10-05 10:00:30')));
    }

    public function test_notifications_listing_does_not_mark_them_read(): void
    {
        $seller = $this->makeSeller();
        $order = $this->makePendingOrder($this->makeCustomer(), $seller);
        $seller->notify(new SellerNewOrderNotification($order));

        $this->as($seller)->getJson('/api/notifications')->assertOk()
            ->assertJsonPath('unread_count', 1)
            ->assertJsonPath('data.0.type', 'SellerNewOrderNotification')
            ->assertJsonPath('data.0.order_id', $order->id);
        $this->assertSame(1, $seller->fresh()->unreadNotifications()->count());

        $this->as($seller)->postJson('/api/notifications/read-all')->assertOk();
        $this->assertSame(0, $seller->fresh()->unreadNotifications()->count());
    }

    public function test_users_sync_is_admin_only(): void
    {
        $this->as($this->makeCustomer())->getJson('/api/sync/users')->assertForbidden();
        $admin = \App\Models\User::factory()->create(['user_type' => 'admin']);
        $this->as($admin)->getJson('/api/sync/users')->assertOk()->assertJsonStructure(['changed', 'all_ids', 'server_time']);
    }
}
