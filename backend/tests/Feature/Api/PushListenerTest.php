<?php

namespace Tests\Feature\Api;

use App\Models\DeviceToken;
use App\Notifications\SellerNewOrderNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Exception\Messaging\NotFound;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\MessageTarget;
use Kreait\Firebase\Messaging\MulticastSendReport;
use Kreait\Firebase\Messaging\SendReport;
use Tests\TestCase;

/** Requiere kreait/laravel-firebase; sin él se omite (el listener no hace nada en ese caso). */
class PushListenerTest extends TestCase
{
    use ApiTestHelpers, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        if (! interface_exists(Messaging::class)) {
            $this->markTestSkipped('kreait/laravel-firebase no está instalado.');
        }
    }

    public function test_a_database_notification_is_pushed_to_the_users_devices_and_dead_tokens_are_removed(): void
    {
        $seller = $this->makeSeller();
        DeviceToken::create(['user_id' => $seller->id, 'token' => 'alive']);
        DeviceToken::create(['user_id' => $seller->id, 'token' => 'uninstalled']);
        $order = $this->makePendingOrder($this->makeCustomer(), $seller);

        $this->mock(Messaging::class, function ($m) use ($order) {
            $m->shouldReceive('sendMulticast')->once()
                ->withArgs(function (CloudMessage $msg, array $tokens) use ($order) {
                    $json = $msg->jsonSerialize();

                    return $tokens == ['alive', 'uninstalled']
                        && $json['notification']['title'] === 'Nueva venta'
                        && $json['data']['order_id'] === (string) $order->id;
                })
                ->andReturn(MulticastSendReport::withItems([
                    SendReport::success(MessageTarget::with('token', 'alive'), []),
                    SendReport::failure(MessageTarget::with('token', 'uninstalled'), NotFound::becauseTokenNotFound('uninstalled')),
                ]));
        });

        $seller->notify(new SellerNewOrderNotification($order));
        app(\Illuminate\Support\Defer\DeferredCallbackCollection::class)->invoke(); // lo que hace Laravel tras responder

        $this->assertSame(['alive'], DeviceToken::pluck('token')->all());
    }

    public function test_a_firebase_failure_does_not_break_the_notification(): void
    {
        $seller = $this->makeSeller();
        DeviceToken::create(['user_id' => $seller->id, 'token' => 'alive']);
        $order = $this->makePendingOrder($this->makeCustomer(), $seller);

        $this->mock(Messaging::class, fn ($m) => $m->shouldReceive('sendMulticast')->andThrow(new \RuntimeException('FCM caído')));

        $seller->notify(new SellerNewOrderNotification($order));
        app(\Illuminate\Support\Defer\DeferredCallbackCollection::class)->invoke();

        $this->assertSame(1, $seller->notifications()->count());
    }

    public function test_users_without_devices_send_nothing(): void
    {
        $seller = $this->makeSeller();
        $this->mock(Messaging::class, fn ($m) => $m->shouldNotReceive('sendMulticast'));

        $seller->notify(new SellerNewOrderNotification($this->makePendingOrder($this->makeCustomer(), $seller)));
        app(\Illuminate\Support\Defer\DeferredCallbackCollection::class)->invoke();
        $this->assertTrue(true);
    }
}
