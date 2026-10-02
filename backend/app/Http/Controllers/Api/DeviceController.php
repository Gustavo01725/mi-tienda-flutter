<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\Request;

/** Registro de tokens FCM de los teléfonos del usuario. */
class DeviceController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'token' => 'required|string|max:512',
            'platform' => 'nullable|in:android,ios',
        ]);

        // updateOrCreate por token: si el teléfono cambia de cuenta, el token pasa al nuevo usuario
        // y deja de recibir los avisos del anterior.
        DeviceToken::updateOrCreate(
            ['token' => $data['token']],
            ['user_id' => $request->user()->id, 'platform' => $data['platform'] ?? null],
        );

        return response()->json(['ok' => true]);
    }

    public function destroy(Request $request)
    {
        $request->validate(['token' => 'required|string']);
        DeviceToken::where('user_id', $request->user()->id)->where('token', $request->token)->delete();

        return response()->json(['ok' => true]);
    }
}
