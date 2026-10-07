<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductPresenter;
use App\Models\Cart;
use App\Models\Product;
use App\Models\ProductStock;
use App\Services\CheckoutService;
use Illuminate\Http\Request;

/**
 * Carrito del usuario (tabla carts, la misma que usa la web). Mismas reglas que
 * App\Http\Controllers\CartController: stock exacto por variante, descuento
 * aplicado al agregar, tope por stock.
 */
class CartController extends Controller
{
    public function __construct(private CheckoutService $checkout) {}

    public function index(Request $request)
    {
        return response()->json($this->payload($request));
    }

    public function add(Request $request)
    {
        $data = $request->validate([
            'product_id' => 'required|exists:products,id',
            'quantity' => 'nullable|integer|min:1',
            'variation' => 'nullable|string|max:100',
        ]);

        $product = Product::active()->with('stocks')->findOrFail($data['product_id']);
        $quantity = $data['quantity'] ?? 1;
        $variant = $data['variation'] ?? null;

        $stock = $variant
            ? $product->stocks->where('variant', $variant)->first()
            : $product->stocks->whereNull('variant')->first();

        if ($product->hasVariants() && ! $stock) {
            return $this->fail($variant ? 'Esa combinación no está disponible.' : 'Elige talla y color antes de agregar al carrito.');
        }
        if (! $stock || $stock->qty <= 0) {
            return $this->fail('Producto agotado.');
        }
        if ($quantity > $stock->qty) {
            return $this->fail("Solo hay {$stock->qty} unidades en stock");
        }

        $price = ProductPresenter::discounted($product, (float) $stock->price);

        $existing = Cart::where('user_id', $request->user()->id)
            ->where('product_id', $product->id)->where('variation', $variant)->first();

        if ($existing) {
            $existing->update(['quantity' => min($existing->quantity + $quantity, $stock->qty), 'price' => $price]);
        } else {
            Cart::create([
                'user_id' => $request->user()->id,
                'product_id' => $product->id,
                'product_stock_id' => $stock->id,
                'variation' => $variant,
                'quantity' => $quantity,
                'price' => $price,
                'tax' => 0,
                'shipping_cost' => $product->shipping_cost ?? 0,
            ]);
        }

        return response()->json($this->payload($request));
    }

    public function update(Request $request, $id)
    {
        $data = $request->validate(['quantity' => 'required|integer|min:1']);
        $item = Cart::where('user_id', $request->user()->id)->findOrFail($id);

        $stock = $item->variation
            ? ProductStock::where('product_id', $item->product_id)->where('variant', $item->variation)->first()
            : ProductStock::where('product_id', $item->product_id)->first();

        // Con el stock agotado (p. ej. vendido en la web) no se deja una línea con cantidad 0.
        if ($stock && $stock->qty <= 0) {
            return $this->fail('Producto agotado.');
        }

        $item->update(['quantity' => min($data['quantity'], $stock?->qty ?? 999)]);

        return response()->json($this->payload($request));
    }

    public function remove(Request $request, $id)
    {
        Cart::where('user_id', $request->user()->id)->findOrFail($id)->delete();

        return response()->json($this->payload($request));
    }

    private function fail(string $message)
    {
        return response()->json(['message' => $message], 422);
    }

    private function payload(Request $request): array
    {
        $items = Cart::where('user_id', $request->user()->id)->with(['product.stocks', 'product.category'])->get();
        $totals = $this->checkout->totals($items);

        return [
            'items' => $items->map(function ($i) {
                $stock = $i->variation
                    ? $i->product?->stocks->where('variant', $i->variation)->first()
                    : $i->product?->stocks->first();

                return [
                    'id' => $i->id,
                    'product_id' => $i->product_id,
                    'name' => $i->product?->name,
                    'thumbnail' => uploaded_asset($i->product?->thumbnail),
                    'variation' => $i->variation,
                    'variant_label' => $i->variant_label,
                    'variant_parts' => $i->variant_parts,
                    'quantity' => (int) $i->quantity,
                    'price' => (float) $i->price,
                    'shipping_cost' => (float) $i->shipping_cost,
                    'available_stock' => $stock?->qty,
                ];
            })->values(),
            'count' => (int) $items->sum('quantity'),
            'subtotal' => $totals['subtotal'],
            'shipping' => $totals['shipping'],
            'tax' => $totals['tax'],
            'total' => $totals['grand_total'],
        ];
    }
}
