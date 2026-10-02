<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\OrderController;
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

    // Push (tokens FCM)
    Route::post('/devices', [DeviceController::class, 'store']);
    Route::delete('/devices', [DeviceController::class, 'destroy']);

    // Avisos (tabla notifications)
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::post('/notifications/{id}/read', [NotificationController::class, 'markRead']);

    // Carrito (tabla carts compartida con la web)
    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart', [CartController::class, 'add']);
    Route::put('/cart/{id}', [CartController::class, 'update'])->whereNumber('id');
    Route::delete('/cart/{id}', [CartController::class, 'remove'])->whereNumber('id');

    // Checkout (Stripe PaymentSheet) y pedidos
    Route::get('/checkout/gateway', [CheckoutController::class, 'gateway']);
    Route::post('/checkout/kushki', [CheckoutController::class, 'kushki']);
    Route::post('/checkout/intent', [CheckoutController::class, 'intent']);
    Route::post('/orders/{id}/confirm-payment', [CheckoutController::class, 'confirm'])->whereNumber('id');
    Route::get('/orders', [OrderController::class, 'index']);
    Route::get('/orders/{id}', [OrderController::class, 'show'])->whereNumber('id');
    Route::get('/sync/orders', [OrderController::class, 'sync']);

    // Inventario del vendedor (admin ve todo)
    Route::middleware('seller')->group(function () {
        Route::get('/seller/products', [SellerProductController::class, 'index']);
        Route::put('/seller/products/{id}', [SellerProductController::class, 'update'])->whereNumber('id');
        Route::get('/seller/orders', [OrderController::class, 'sellerIndex']);
        Route::post('/seller/orders/{id}/confirm', [OrderController::class, 'confirm'])->whereNumber('id');
        Route::post('/seller/orders/{id}/send-to-warehouse', [OrderController::class, 'sendToWarehouse'])->whereNumber('id');
        Route::put('/seller/products/{id}/stocks', [SellerProductController::class, 'updateStocks'])->whereNumber('id');
    });

    // Usuarios (solo admin)
    Route::middleware('admin.api')->group(function () {
        Route::get('/admin/users', [UserController::class, 'index']);
        Route::get('/sync/users', [SyncController::class, 'users']);
    });
});
