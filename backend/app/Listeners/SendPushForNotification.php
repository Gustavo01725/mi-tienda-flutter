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
    public function handle(NotificationSent $event): void
    {
        // Laravel 11/12 descubre este listener solo (por el tipo de $event en handle). Si kreait aún
        // no está instalado o configurado, no hace nada: nunca debe romper un aviso de la web.
        if (! interface_exists(Messaging::class)) {
            return;
        }

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

        $title = $this->title($event->notification);
        $orderId = isset($data['order_id']) ? (string) $data['order_id'] : null;

        // Se envía después de responder (o al terminar el comando/trabajo): una llamada lenta a FCM
        // no debe alargar ni tumbar la acción que generó el aviso (p. ej. "Enviar al almacén", que
        // avisa a todos los admins). always: el aviso ya quedó guardado aunque la respuesta falle luego.
        \Illuminate\Support\defer(fn () => $this->send($tokens, $title, $message, $orderId), always: true);
    }

    private function send(array $tokens, string $title, string $message, ?string $orderId): void
    {
        try {
            $cloud = CloudMessage::new()
                ->withNotification(FcmNotification::create($title, $message))
                ->withData(array_filter(['order_id' => $orderId]));

            $report = app(Messaging::class)->sendMulticast($cloud, $tokens);

            // Se limpian los tokens muertos: FCM marca como "unknown" los de apps desinstaladas o
            // sesiones caducadas, e "invalid" los mal formados. Los demás fallos son transitorios.
            if ($report->hasFailures()) {
                DeviceToken::whereIn('token', [...$report->unknownTokens(), ...$report->invalidTokens()])->delete();
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
