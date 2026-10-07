<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WalletRecharge;
use App\Models\WalletWithdrawal;
use Illuminate\Http\Request;

/**
 * Billetera en solo lectura: saldo e historial, como /wallet de la web. Recargar (sube un
 * comprobante) y retirar (liquidaciones del vendedor) se hacen en la web, que tiene esos flujos.
 */
class WalletController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'balance' => (float) $user->balance,
            'recharges' => WalletRecharge::where('user_id', $user->id)->latest()->limit(50)->get()
                ->map(fn ($r) => [
                    'id' => $r->id,
                    'amount' => (float) $r->amount,
                    // approval: 1 aprobada, 0 pendiente, otro valor rechazada (vista users/wallet de la web).
                    'status' => match ((int) $r->approval) { 1 => 'approved', 0 => 'pending', default => 'rejected' },
                    'created_at' => $r->created_at?->toIso8601String(),
                ])->values(),
            'withdrawals' => WalletWithdrawal::where('user_id', $user->id)->latest()->limit(50)->get()
                ->map(fn ($w) => [
                    'id' => $w->id,
                    'amount' => (float) $w->amount,
                    'status' => $w->status,
                    'bank_name' => $w->bank_name,
                    'created_at' => $w->created_at?->toIso8601String(),
                ])->values(),
        ]);
    }
}
