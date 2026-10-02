<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/** Versión JSON de la regla de /seller/*: vendedor con tienda aprobada, o admin. */
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

        return $next($request);
    }
}
