<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/** Versión JSON de la regla de /seller/*: vendedor con tienda aprobada y correo verificado, o admin. */
class EnsureSellerApi
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();

        if ($user->isAdmin()) {
            return $next($request);
        }

        $approved = $user->isSeller() && \App\Models\Shop::where('user_id', $user->id)->where('status', 1)->exists();
        abort_unless($approved, 403, 'Tienda no aprobada.');

        // Mismo requisito que SellerProductController de la web.
        abort_unless($user->isVerified(), 403, 'Debes verificar tu correo electrónico antes de usar el panel de vendedor.');

        return $next($request);
    }
}
