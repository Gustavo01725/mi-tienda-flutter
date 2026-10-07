import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/catalog_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import '../widgets/product_cards.dart';

/// Portada: las mismas secciones y en el mismo orden que home.blade.php de la web.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    final products = catalog.products;
    final cats = catalog.categories;

    final newest = [...products]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final featured = products.where((p) => p.featured).toList();
    final bestSelling = [...products]..sort((a, b) => b.numOfSale.compareTo(a.numOfSale));
    final bestRated = [...products]..sort((a, b) => b.rating.compareTo(a.rating));
    final topCats = cats.where((c) => c.parentId == null).toList();

    return GuScaffold(
      active: AppPage.home,
      onRefresh: () async {
        await Future.wait([catalog.sync(), catalog.loadCategories()]);
      },
      slivers: [
        if (catalog.error != null) SliverToBoxAdapter(child: _ErrorBanner(catalog.error!, onRetry: catalog.sync)),
        if (topCats.isNotEmpty) SliverToBoxAdapter(child: _CategoryStrip(topCats.take(6).toList())),
        if (products.isEmpty && catalog.error == null)
          const SliverToBoxAdapter(
            child: GuCard(
              margin: EdgeInsets.fromLTRB(15, 20, 15, 16),
              child: EmptyState(icon: LineAwesomeIcons.box_open_solid, text: 'Todavía no hay productos publicados.'),
            ),
          ),
        if (newest.isNotEmpty) SliverToBoxAdapter(child: _ProductSection('New Products', newest.take(12).toList())),
        if (featured.isNotEmpty)
          SliverToBoxAdapter(child: _ProductSection('Productos destacados', featured.take(12).toList(), star: true)),
        if (bestSelling.isNotEmpty) SliverToBoxAdapter(child: _ProductSection('Más vendidos', bestSelling.take(12).toList())),
        if (topCats.isNotEmpty) SliverToBoxAdapter(child: _ShopByCategory(topCats.take(6).toList())),
        if (bestRated.isNotEmpty) SliverToBoxAdapter(child: _ProductSection('Los más vendidos', bestRated.take(12).toList())),
        if (cats.isNotEmpty) SliverToBoxAdapter(child: _TopCategories(cats.take(10).toList())),
        const SliverToBoxAdapter(child: PoliciesGrid()),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner(this.message, {required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(15, 16, 15, 0),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          border: Border.all(color: const Color(0xFFFFD8A8)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          const Icon(LineAwesomeIcons.exclamation_triangle_solid, color: Color(0xFFB7791F)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      );
}

/// Fila de categorías bajo la cabecera (tarjetas blancas con imagen y nombre).
class _CategoryStrip extends StatelessWidget {
  final List<ShopCategory> cats;
  const _CategoryStrip(this.cats);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 150,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(15, 20, 15, 10),
          scrollDirection: Axis.horizontal,
          itemCount: cats.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => context.read<NavState>().openProducts(categoryId: cats[i].id),
            child: Container(
              width: 123,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: cardShadow),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 78, width: double.infinity, child: NetImg(cats[i].image)),
                const SizedBox(height: 8),
                Text(cats[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xB31B1B28))),
              ]),
            ),
          ),
        ),
      );
}

/// Sección blanca con título subrayado y carrusel horizontal de productos.
class _ProductSection extends StatelessWidget {
  final String title;
  final List<Product> products;
  final bool star;
  const _ProductSection(this.title, this.products, {this.star = false});

  @override
  Widget build(BuildContext context) => GuCard(
        margin: const EdgeInsets.fromLTRB(15, 10, 15, 16),
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(star ? '★ $title' : title),
          SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => HomeProductCard(products[i]),
            ),
          ),
        ]),
      );
}

/// "Compra por categoría": cuadros verde claro con imagen y nombre.
class _ShopByCategory extends StatelessWidget {
  final List<ShopCategory> cats;
  const _ShopByCategory(this.cats);

  @override
  Widget build(BuildContext context) => GuCard(
        margin: const EdgeInsets.fromLTRB(15, 10, 15, 16),
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Compra por categoría'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.48,
            children: [
              for (final c in cats)
                GestureDetector(
                  onTap: () => context.read<NavState>().openProducts(categoryId: c.id),
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.tile, borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.all(12),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 60, height: 60, child: NetImg(c.image)),
                      const SizedBox(height: 10),
                      Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ],
          ),
        ]),
      );
}

/// "Top 10 categorías" con el botón verde "Ver todas las categorías".
class _TopCategories extends StatelessWidget {
  final List<ShopCategory> cats;
  const _TopCategories(this.cats);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(
            'Top 10 categorías',
            trailing: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontFamily: 'OpenSans', fontSize: 12.5),
              ),
              onPressed: () => context.read<NavState>().go(AppPage.categories),
              child: const Text('Ver todas las categorías'),
            ),
          ),
          for (final c in cats)
            GestureDetector(
              onTap: () => context.read<NavState>().openProducts(categoryId: c.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  SizedBox(width: 60, height: 60, child: NetImg(c.image)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  const Icon(LineAwesomeIcons.angle_right_solid, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                ]),
              ),
            ),
        ]),
      );
}

/// Las cuatro políticas del pie de la web (enlazan a sus páginas).
class PoliciesGrid extends StatelessWidget {
  const PoliciesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (LineAwesomeIcons.file_alt, 'Términos y\ncondiciones', '/terms'),
      (LineAwesomeIcons.undo_solid, 'Política de\ndevoluciones', '/return-policy'),
      (LineAwesomeIcons.life_ring, 'Política de soporte', '/support-policy'),
      (LineAwesomeIcons.exclamation_circle_solid, 'Política de privacidad', '/privacy-policy'),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.7,
        children: [
          for (final (icon, label, path) in items)
            InkWell(
              onTap: () => openWeb(context, path),
              child: Container(
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border))),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: AppColors.primary, size: 36),
                  const SizedBox(height: 8),
                  Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
