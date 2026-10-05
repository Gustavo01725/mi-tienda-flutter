<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductPresenter;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Gestión de inventario desde la app. Misma regla de propiedad que la web. */
class SellerProductController extends Controller
{
    public function index(Request $request)
    {
        $q = Product::with(['stocks', 'category', 'brand'])->latest('id');
        if (! $request->user()->isAdmin()) {
            $q->where('added_by', $request->user()->id);
        }
        $q->search($request->query('q'));

        return response()->json($q->get()->map(fn ($p) => ProductPresenter::make($p))->values());
    }

    public function update(Request $request, $id)
    {
        $product = $this->owned($request, $id);

        $data = $request->validate([
            'name' => 'sometimes|string|max:255',
            'unit_price' => 'sometimes|numeric|min:0',
            // Un porcentaje no puede pasar de 100 ni un descuento fijo del precio: el precio quedaría negativo.
            'discount' => ['sometimes', 'integer', 'min:0', 'max:'.($product->discount_type === 'percent'
                ? 100
                : (int) floor($request->input('unit_price', $product->unit_price)))],
            'published' => 'sometimes|boolean',
            'featured' => 'sometimes|boolean',
        ]);
        $product->update($data);

        return response()->json(ProductPresenter::make($product->fresh()));
    }

    /** Cambia cantidad (y opcionalmente precio) de filas de stock existentes. */
    public function updateStocks(Request $request, $id)
    {
        $product = $this->owned($request, $id);

        $request->validate([
            'stocks' => 'required|array|min:1',
            'stocks.*.id' => 'required|integer',
            'stocks.*.qty' => 'required|integer|min:0',
            'stocks.*.price' => 'nullable|numeric|min:0',
        ]);

        // Todo o nada: si una fila no es de este producto, no queda ninguna a medio guardar.
        DB::transaction(function () use ($product, $request) {
            foreach ($request->stocks as $row) {
                $stock = $product->stocks()->findOrFail($row['id']);
                $stock->qty = $row['qty'];
                if (isset($row['price'])) {
                    $stock->price = $row['price'];
                }
                $stock->save(); // dispara $touches → products.updated_at
            }
        });

        return response()->json(ProductPresenter::make($product->fresh()));
    }

    private function owned(Request $request, $id): Product
    {
        $product = Product::with('stocks')->findOrFail($id);
        abort_unless($product->added_by === $request->user()->id || $request->user()->isAdmin(), 403, 'No autorizado.');

        return $product;
    }
}
