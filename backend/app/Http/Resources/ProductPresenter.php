<?php

namespace App\Http\Resources;

use App\Models\Product;

/**
 * Convierte un Product en el JSON que consume la app. Usa las mismas reglas de
 * precio, variantes y rutas de imagen que la web (uploaded_asset, stockMap...).
 */
class ProductPresenter
{
    public static function make(Product $p): array
    {
        $p->loadMissing(['stocks', 'category', 'brand']);

        return [
            'id' => $p->id,
            'name' => $p->name,
            'slug' => $p->slug,
            'category_id' => $p->category_id,
            'category' => $p->category?->name,
            'brand' => $p->brand?->name,
            'added_by' => $p->added_by,
            'unit' => $p->unit,
            'unit_price' => (float) $p->unit_price,
            'discount' => (int) $p->discount,
            'discount_type' => $p->discount_type,
            'price' => round((float) $p->discounted_price, 2),
            'thumbnail' => uploaded_asset($p->thumbnail),
            'photos' => collect($p->photos ?? [])->map(fn ($f) => uploaded_asset($f))->values(),
            'short_description' => $p->short_description,
            'description' => $p->description,
            'min_qty' => (int) $p->min_qty,
            'low_stock_qty' => (int) $p->low_stock_qty,
            'rating' => (float) $p->rating,
            'reviews_count' => (int) $p->reviews_count,
            'featured' => (bool) $p->featured,
            'published' => (bool) $p->published,
            'approved' => (bool) $p->approved,
            'shipping_cost' => (float) $p->shipping_cost,
            'total_stock' => (int) $p->stocks->sum('qty'),
            'stocks' => $p->stocks->map(fn ($s) => [
                'id' => $s->id,
                'size' => $s->size,
                'color' => $s->color,
                'variant' => \App\Models\ProductStock::buildVariant($s->size, $s->color),
                'price' => (float) $s->price,
                'qty' => (int) $s->qty,
                'sku' => $s->sku,
            ])->values(),
            'updated_at' => $p->updated_at?->toIso8601String(),
        ];
    }
}
