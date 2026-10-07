import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/catalog_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import '../widgets/product_cards.dart';

/// "Todos los productos" (products.blade.php): título con el total, orden, buscador y rejilla.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final TextEditingController _q;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: context.read<NavState>().query);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  List<Product> _filter(List<Product> all, NavState nav) {
    final q = _norm(nav.query.trim());
    final list = all.where((p) {
      if (nav.categoryId != null && p.categoryId != nav.categoryId) return false;
      if (q.isEmpty) return true;
      return _norm(p.name).contains(q) || _norm(p.shortDescription ?? '').contains(q);
    }).toList();
    switch (nav.sort) {
      case ProductSort.newest:
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      case ProductSort.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
      case ProductSort.bestSelling:
        list.sort((a, b) => b.numOfSale.compareTo(a.numOfSale));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavState>();
    final catalog = context.watch<CatalogState>();
    if (_q.text != nav.query) _q.text = nav.query; // búsqueda lanzada desde la cabecera
    final items = _filter(catalog.products, nav);
    final cat = catalog.categoryById(nav.categoryId);

    return GuScaffold(
      active: AppPage.products,
      onRefresh: catalog.sync,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 24, 15, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                      text: cat?.name ?? 'Todos los productos',
                      style: const TextStyle(fontSize: 17.6, fontWeight: FontWeight.w700, color: Color(0xFF222222)),
                    ),
                    TextSpan(text: '  (${items.length})', style: const TextStyle(fontSize: 13, color: AppColors.muted3)),
                  ])),
                ),
                Container(
                  height: 36,
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ProductSort>(
                      value: nav.sort,
                      style: const TextStyle(fontFamily: 'OpenSans', fontSize: 13, color: Color(0xFF333333)),
                      onChanged: (s) => nav.setSort(s!),
                      items: const [
                        DropdownMenuItem(value: ProductSort.newest, child: Text('Más recientes')),
                        DropdownMenuItem(value: ProductSort.priceAsc, child: Text('Precio: menor a mayor')),
                        DropdownMenuItem(value: ProductSort.priceDesc, child: Text('Precio: mayor a menor')),
                        DropdownMenuItem(value: ProductSort.bestSelling, child: Text('Más vendidos')),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) => nav.openProducts(query: v, categoryId: nav.categoryId),
                    decoration: const InputDecoration(
                      hintText: 'Buscar productos...',
                      border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.horizontal(left: Radius.circular(4))),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.horizontal(left: Radius.circular(4))),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 42,
                  width: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(4))),
                    ),
                    onPressed: () => nav.openProducts(query: _q.text, categoryId: nav.categoryId),
                    child: Transform.flip(flipX: true, child: const Icon(LineAwesomeIcons.search_solid, size: 18)),
                  ),
                ),
              ]),
              if (nav.categoryId != null || nav.query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(spacing: 8, children: [
                    if (cat != null)
                      InputChip(
                        label: Text(cat.name),
                        onDeleted: () => nav.openProducts(query: nav.query),
                        backgroundColor: AppColors.softPrimary,
                        side: BorderSide.none,
                      ),
                    if (nav.query.isNotEmpty)
                      InputChip(
                        label: Text('“${nav.query}”'),
                        onDeleted: () => nav.openProducts(categoryId: nav.categoryId),
                        backgroundColor: AppColors.softPrimary,
                        side: BorderSide.none,
                      ),
                  ]),
                ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: LineAwesomeIcons.search_solid,
              text: catalog.error ?? 'No encontramos productos con esos filtros.',
              action: nav.categoryId != null || nav.query.isNotEmpty
                  ? OutlinedButton(onPressed: nav.clearFilters, child: const Text('Ver todos los productos'))
                  : null,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => ListingProductCard(items[i]),
            ),
          ),
      ],
    );
  }
}
