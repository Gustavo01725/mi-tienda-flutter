<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\SellerProductController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Controllers\Api\UserController;
use Illuminate\Support\Facades\Route;

// Público
Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');
Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:10,1');

Route::get('/categories', [CatalogController::class, 'categories']);
Route::get('/products', [CatalogController::class, 'products']);
Route::get('/products/{id}', [CatalogController::class, 'show'])->whereNumber('id');

// Sincronización incremental (la app la consulta cada pocos segundos)
Route::get('/sync/products', [SyncController::class, 'products']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    // Inventario del vendedor (admin ve todo)
    Route::middleware('seller')->group(function () {
        Route::get('/seller/products', [SellerProductController::class, 'index']);
        Route::put('/seller/products/{id}', [SellerProductController::class, 'update'])->whereNumber('id');
        Route::put('/seller/products/{id}/stocks', [SellerProductController::class, 'updateStocks'])->whereNumber('id');
    });

    // Usuarios (solo admin)
    Route::middleware('admin.api')->group(function () {
        Route::get('/admin/users', [UserController::class, 'index']);
        Route::get('/sync/users', [SyncController::class, 'users']);
    });
});
