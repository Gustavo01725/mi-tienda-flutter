<?php

namespace App\Listeners;

use App\Models\DeviceToken;
use Illuminate\Notifications\Events\NotificationSent;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification as FcmNotification;
use Throwable;

/**
 * Convierte en push cada notificación de base de datos que la web ya genera (pedido confirmado,
 * nueva venta, tienda aprobada...), sin tocar esas clases: todas guardan su texto en data.message.
 * Un fallo de FCM nunca debe romper la acción que generó el aviso, por eso se captura todo.
 */
class SendPushForNotification
{
    public function __construct(private Messaging $messaging) {}

    public function handle(NotificationSent $event): void
    {
        // La notificación ya se escribe en 'database'; solo se duplica ese canal, una vez por aviso.
        if ($event->channel !== 'database' || ! $event->notifiable instanceof \App\Models\User) {
            return;
        }

        $tokens = DeviceToken::where('user_id', $event->notifiable->id)->pluck('token')->all();
        if (! $tokens) {
            return;
        }

        $data = $event->notification->toArray($event->notifiable);
        $message = $data['message'] ?? null;
        if (! $message) {
            return;
        }

        try {
            $cloud = CloudMessage::new()
                ->withNotification(FcmNotification::create($this->title($event->notification), $message))
                ->withData(array_filter(['order_id' => isset($data['order_id']) ? (string) $data['order_id'] : null]));

            $report = $this->messaging->sendMulticast($cloud, $tokens);

            // Tokens de teléfonos que desinstalaron la app: se limpian.
            if ($report->hasFailures()) {
                DeviceToken::whereIn('token', $report->invalidTokens())->delete();
            }
        } catch (Throwable $e) {
            Log::warning('FCM: no se pudo enviar el push', ['error' => $e->getMessage()]);
        }
    }

    private function title(object $notification): string
    {
        return match (class_basename($notification)) {
            'SellerNewOrderNotification' => 'Nueva venta',
            'OrderArrivedWarehouseNotification' => 'Pedido en almacén',
            'ShopStatusUpdatedNotification' => 'Tu tienda',
            'SellerSettledNotification' => 'Liquidación',
            default => 'Tu pedido',
        };
    }
}
