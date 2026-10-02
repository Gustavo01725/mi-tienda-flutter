<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/** EnsureUserIsAdmin usa Auth::check() (guard de sesión); con token Sanctum hay que mirar $request->user(). */
class EnsureAdminApi
{
    public function handle(Request $request, Closure $next)
    {
        abort_unless($request->user()?->isAdmin(), 403, 'No autorizado.');

        return $next($request);
    }
}
