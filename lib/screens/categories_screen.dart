import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../services/catalog_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';

/// "Todas las categorías" (categories.blade.php).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    final nav = context.read<NavState>();
    final parents = catalog.categories.where((c) => c.parentId == null).toList();
    return GuScaffold(
      active: AppPage.categories,
      onRefresh: catalog.loadCategories,
      slivers: [
        SliverToBoxAdapter(child: Breadcrumb([('Inicio', () => nav.go(AppPage.home)), ('Todas las categorías', null)])),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Todas las categorías', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
              TextSpan(
                text: '    ${parents.length} ${parents.length == 1 ? 'categoría' : 'categorías'}',
                style: const TextStyle(fontSize: 12.8, color: AppColors.muted2),
              ),
            ])),
          ),
        ),
        if (parents.isEmpty)
          const SliverToBoxAdapter(child: EmptyState(icon: LineAwesomeIcons.list_ul_solid, text: 'No hay categorías todavía.'))
        else
          SliverList.builder(
            itemCount: parents.length,
            itemBuilder: (_, i) {
              final c = parents[i];
              final children = catalog.categories.where((x) => x.parentId == c.id).toList();
              return Container(
                margin: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  InkWell(
                    onTap: () => nav.openProducts(categoryId: c.id),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 52, height: 52, child: NetImg(c.image))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('${c.productsCount} ${c.productsCount == 1 ? 'producto' : 'productos'}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted3)),
                          ]),
                        ),
                        const Icon(LineAwesomeIcons.angle_right_solid, size: 16, color: AppColors.primary),
                      ]),
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: children.isEmpty
                          ? const Text('Sin subcategorías',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFFAAAAAA), fontStyle: FontStyle.italic))
                          : Wrap(spacing: 8, runSpacing: 6, children: [
                              for (final ch in children)
                                ActionChip(
                                  label: Text(ch.name, style: const TextStyle(fontSize: 12)),
                                  onPressed: () => nav.openProducts(categoryId: ch.id),
                                  backgroundColor: AppColors.field,
                                  side: const BorderSide(color: AppColors.borderLight),
                                ),
                            ]),
                    ),
                  ),
                ]),
              );
            },
          ),
      ],
    );
  }
}
