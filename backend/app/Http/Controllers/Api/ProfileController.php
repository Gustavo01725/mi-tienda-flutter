<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

/** "Mi perfil" de la app: mismas reglas y mensajes que ProfileController de la web. */
class ProfileController extends Controller
{
    public function update(Request $request)
    {
        $user = $request->user();
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email,'.$user->id,
            'phone' => 'nullable|string|max:20',
        ], [
            'name.required' => 'El nombre es obligatorio.',
            'email.required' => 'El correo es obligatorio.',
            'email.unique' => 'Este correo ya está en uso.',
        ]);

        $user->name = $data['name'];
        $user->email = $data['email'];
        $user->phone = $data['phone'] ?? null;
        $user->save();

        return response()->json(AuthController::userJson($user));
    }

    public function password(Request $request)
    {
        $request->validate([
            'current_password' => 'required',
            'password' => ['required', 'confirmed', Password::min(8)],
        ], [
            'current_password.required' => 'Ingresa tu contraseña actual.',
            'password.required' => 'La nueva contraseña es obligatoria.',
            'password.confirmed' => 'Las contraseñas no coinciden.',
        ]);

        if (! Hash::check($request->current_password, $request->user()->password)) {
            return response()->json([
                'message' => 'La contraseña actual no es correcta.',
                'errors' => ['current_password' => ['La contraseña actual no es correcta.']],
            ], 422);
        }

        $request->user()->update(['password' => Hash::make($request->password)]);

        return response()->json(['ok' => true]);
    }
}
