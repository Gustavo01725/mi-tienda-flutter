<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Notifications\VerifyEmailNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
            'device' => 'nullable|string|max:60',
        ]);

        // 5 intentos fallidos por minuto para un mismo correo desde una misma IP.
        $key = 'api-login:'.Str::lower($data['email']).'|'.$request->ip();
        if (RateLimiter::tooManyAttempts($key, 5)) {
            return response()->json([
                'message' => 'Demasiados intentos. Prueba de nuevo en '.RateLimiter::availableIn($key).' segundos.',
            ], 429);
        }

        // Mismo criterio que la web: Auth::attempt sobre users.
        if (! Auth::validate(['email' => $data['email'], 'password' => $data['password']])) {
            RateLimiter::hit($key, 60);
            throw ValidationException::withMessages(['email' => 'Correo o contraseña incorrectos.']);
        }
        RateLimiter::clear($key);

        $user = User::where('email', $data['email'])->firstOrFail();

        if ($user->banned) {
            throw ValidationException::withMessages(['email' => 'Cuenta suspendida.']);
        }

        return response()->json([
            'token' => $user->createToken($data['device'] ?? 'flutter')->plainTextToken,
            'user' => $this->userJson($user),
        ]);
    }

    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6',
            'phone' => 'nullable|string|max:20',
        ]);

        // user_type no es asignable en masa: se fija aparte, como en RegisterController de la web.
        // (Con el default de la columna, el modelo recién creado lo devolvía como null.)
        $user = new User($data);
        $user->user_type = 'customer';
        $user->save();

        // Igual que RegisterController de la web. Un fallo de correo no debe impedir el registro.
        try {
            $user->notify(new VerifyEmailNotification());
        } catch (\Throwable $e) {
            Log::warning('No se pudo enviar el correo de verificación (api)', ['user_id' => $user->id, 'error' => $e->getMessage()]);
        }

        return response()->json([
            'token' => $user->createToken('flutter')->plainTextToken,
            'user' => $this->userJson($user),
        ], 201);
    }

    public function me(Request $request)
    {
        return response()->json($this->userJson($request->user()));
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['ok' => true]);
    }

    public static function userJson(User $u): array
    {
        return [
            'id' => $u->id,
            'name' => $u->name,
            'email' => $u->email,
            'phone' => $u->phone,
            'user_type' => $u->user_type,
            'verified' => $u->isVerified(),
            'banned' => (bool) $u->banned,
            'balance' => (float) $u->balance,
            'updated_at' => $u->updated_at?->toIso8601String(),
        ];
    }
}
