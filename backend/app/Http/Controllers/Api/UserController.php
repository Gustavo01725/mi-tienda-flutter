<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $q = User::query()->latest('id');
        if ($s = trim((string) $request->query('q'))) {
            $q->where(fn ($w) => $w->where('name', 'like', "%$s%")->orWhere('email', 'like', "%$s%"));
        }
        $page = $q->paginate(30);

        return response()->json([
            'data' => $page->getCollection()->map(fn ($u) => AuthController::userJson($u))->values(),
            'current_page' => $page->currentPage(),
            'last_page' => $page->lastPage(),
        ]);
    }
}
