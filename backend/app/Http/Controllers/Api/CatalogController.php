<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductPresenter;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Http\Request;

class CatalogController extends Controller
{
    /** Categorías activas con su imagen y cuántos productos publicados tienen (como /categories de la web). */
    public function categories()
    {
        return Category::active()
            ->withCount(['products as products_count' => fn ($q) => $q->active()])
            ->orderBy('order')->orderBy('name')
            ->get()
            ->map(fn ($c) => [
                'id' => $c->id,
                'name' => $c->name,
                'slug' => $c->slug,
                'parent_id' => $c->parent_id,
                'featured' => (bool) $c->featured,
                'icon' => $c->icon ? uploaded_asset($c->icon) : null,
                'banner' => $c->banner ? uploaded_asset($c->banner) : null,
                'products_count' => (int) $c->products_count,
            ])->values();
    }

    public function products(Request $request)
    {
        $q = Product::active()->with(['stocks', 'category', 'brand']);

        if ($request->filled('category_id')) {
            $q->where('category_id', $request->integer('category_id'));
        }
        if ($request->boolean('featured')) {
            $q->featured();
        }
        $q->search($request->query('q'), ['name', 'short_description']);

        $page = $q->latest('id')->paginate(max(1, min($request->integer('per_page', 20), 50)));

        return response()->json([
            'data' => $page->getCollection()->map(fn ($p) => ProductPresenter::make($p))->values(),
            'current_page' => $page->currentPage(),
            'last_page' => $page->lastPage(),
        ]);
    }

    public function show($id)
    {
        $p = Product::active()->with(['stocks', 'category', 'brand'])->findOrFail($id);

        return response()->json(ProductPresenter::make($p));
    }
}
