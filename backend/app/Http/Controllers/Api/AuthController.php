<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
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

        // Mismo criterio que la web: Auth::attempt sobre users.
        if (! Auth::validate(['email' => $data['email'], 'password' => $data['password']])) {
            throw ValidationException::withMessages(['email' => 'Correo o contraseña incorrectos.']);
        }

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

        // user_type queda en su default ('customer'): no es asignable en masa.
        $user = User::create($data);

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
