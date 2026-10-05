<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductPresenter;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Http\Request;

class CatalogController extends Controller
{
    public function categories()
    {
        return Category::active()->orderBy('order')->orderBy('name')
            ->get(['id', 'name', 'slug', 'parent_id', 'icon', 'variant_type']);
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
