import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/auth_state.dart';
import '../services/cart_state.dart';
import '../services/catalog_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'login_screen.dart';

/// Ficha de producto (product-detail.blade.php). Lee el producto del catálogo en cada build:
/// el stock y el precio cambian en vivo cuando alguien los modifica en la web.
class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _size, _color;
  int _qty = 1, _photo = 0, _tab = 0;
  bool _busy = false;

  /// Clave de la variante igual que ProductStock::buildVariant(): talla y color unidos por "-".
  String get _variant => [_size, _color].where((e) => e != null && e.isNotEmpty).join('-');

  Stock? _selectedStock(Product p) {
    final hasVariants = p.stocks.any((s) => s.variant.isNotEmpty);
    if (!hasVariants) return p.stocks.firstOrNull;
    return p.stocks.where((s) => s.variant == _variant).firstOrNull;
  }

  bool _sizeAvailable(Product p, String size) =>
      p.stocks.any((s) => s.size == size && s.qty > 0 && (_color == null || s.color == null || s.color == _color));

  bool _colorAvailable(Product p, String color) =>
      p.stocks.any((s) => s.color == color && s.qty > 0 && (_size == null || s.size == null || s.size == _size));

  Future<bool> _add(Product p, Stock? stock) async {
    final hasVariants = p.stocks.any((s) => s.variant.isNotEmpty);
    if (context.read<AuthState>().user == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return false;
    }
    if (hasVariants && stock == null) {
      final need = [if (p.sizes.isNotEmpty && _size == null) 'talla', if (p.colors.isNotEmpty && _color == null) 'color'];
      _snack(need.isEmpty ? 'Esa combinación no está disponible.' : 'Elige ${need.join(' y ')} antes de agregar al carrito.');
      return false;
    }
    setState(() => _busy = true);
    try {
      await context.read<CartState>().add(p.id, variation: hasVariants ? _variant : null, quantity: _qty);
      return true;
    } catch (e) {
      _snack('$e');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavState>();
    final p = context.watch<CatalogState>().byId(widget.productId);
    if (p == null) {
      return GuScaffold(
        slivers: [
          SliverToBoxAdapter(
            child: EmptyState(
              icon: LineAwesomeIcons.box_open_solid,
              text: 'Este producto ya no está disponible.',
              action: FilledButton(onPressed: () => nav.go(AppPage.products), child: const Text('Ver productos')),
            ),
          ),
        ],
      );
    }

    // Si la talla/color elegidos se agotaron en la web mientras se miraba, se sueltan.
    if (_size != null && !_sizeAvailable(p, _size!)) _size = null;
    if (_color != null && !_colorAvailable(p, _color!)) _color = null;
    final stock = _selectedStock(p);
    // Sin la combinación completa elegida: lo que hay de la talla/color ya elegidos (como en la web).
    final maxQty = stock?.qty ??
        p.stocks
            .where((s) => (_size == null || s.size == _size) && (_color == null || s.color == _color))
            .fold<int>(0, (sum, s) => sum + s.qty);
    if (_qty > maxQty && maxQty > 0) _qty = maxQty;
    final price = stock?.finalPrice ?? p.price;
    final original = stock?.price ?? p.unitPrice;
    final photos = [p.thumbnail, ...p.photos];
    const label = TextStyle(fontSize: 13.3, color: AppColors.muted3);

    Widget row(String name, Widget child) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 84,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(name, style: label),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );

    final cat = context.read<CatalogState>().categoryById(p.categoryId);
    return GuScaffold(
      active: AppPage.products,
      slivers: [
        SliverToBoxAdapter(
          child: Breadcrumb([
            ('Inicio', () => nav.go(AppPage.home)),
            if (p.category != null) (p.category!, cat == null ? null : () => nav.openProducts(categoryId: cat.id)),
            (p.name, null),
          ]),
        ),
        SliverToBoxAdapter(
          child: GuCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PageView(
                    onPageChanged: (i) => setState(() => _photo = i),
                    children: [for (final url in photos) NetImg(url, fit: BoxFit.contain)],
                  ),
                ),
                if (photos.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _photo ? AppColors.primary : AppColors.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Stars(p.rating, size: 13, outline: true),
                    const SizedBox(width: 6),
                    Text('(${p.reviewsCount} reseñas)', style: const TextStyle(fontSize: 12.5, color: AppColors.muted2)),
                  ],
                ),
                const SizedBox(height: 12),
                row(
                  'Precio:',
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: money(price),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                            if (p.unit != null && p.unit!.isNotEmpty)
                              TextSpan(
                                text: ' /${p.unit}',
                                style: const TextStyle(fontSize: 13, color: AppColors.muted2),
                              ),
                          ],
                        ),
                      ),
                      if (original > price)
                        Text(
                          money(original),
                          style: const TextStyle(fontSize: 13.6, color: AppColors.strike, decoration: TextDecoration.lineThrough),
                        ),
                      if (p.discountPercent > 0)
                        Pill('-${p.discountPercent}%', color: AppColors.danger, background: AppColors.dangerSoft),
                    ],
                  ),
                ),
                if (p.sizes.isNotEmpty)
                  row(
                    '${p.sizeLabel ?? 'Talla'}:',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in p.sizes)
                          _SizeBox(
                            s,
                            selected: _size == s,
                            enabled: _sizeAvailable(p, s),
                            onTap: () => setState(() => _size = _size == s ? null : s),
                          ),
                      ],
                    ),
                  ),
                if (p.colors.isNotEmpty)
                  row(
                    'Color:',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in p.colors)
                          _ColorBox(
                            c,
                            selected: _color == c.color,
                            enabled: _colorAvailable(p, c.color!),
                            onTap: () => setState(() => _color = _color == c.color ? null : c.color),
                          ),
                      ],
                    ),
                  ),
                row(
                  'Cantidad:',
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      QtyStepper(
                        value: _qty,
                        max: maxQty > 0 ? maxQty : 1,
                        onChanged: maxQty > 0 ? (v) => setState(() => _qty = v) : null,
                      ),
                      Text(
                        maxQty > 0 ? '($maxQty disponibles)' : '(Agotado)',
                        style: TextStyle(fontSize: 12.8, color: maxQty > 0 ? AppColors.muted2 : AppColors.danger),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(LineAwesomeIcons.cart_plus_solid, size: 18),
                    label: Text(p.totalStock == 0 ? 'Agotado' : 'Añadir al carrito'),
                    onPressed: _busy || p.totalStock == 0
                        ? null
                        : () async {
                            if (await _add(p, stock) && mounted) _snack('Producto añadido al carrito');
                          },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(LineAwesomeIcons.bolt_solid, size: 18),
                    label: const Text('Comprar ahora'),
                    onPressed: _busy || p.totalStock == 0
                        ? null
                        : () async {
                            if (await _add(p, stock) && mounted) nav.go(AppPage.cart);
                          },
                  ),
                ),
                const SizedBox(height: 14),
                row(
                  'Reembolso:',
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6FBF2),
                      border: Border.all(color: const Color(0xFFD4E7C5)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LineAwesomeIcons.shield_alt_solid, color: AppColors.primary, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Protección de reembolso', style: TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    'Garantía de devolución de 30 días',
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textSoft),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => openWeb(context, '/return-policy'),
                          child: const Text('Ver política', style: TextStyle(color: AppColors.primary, fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: GuCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final (i, t) in [(0, 'Descripción'), (1, 'Reseñas (${p.reviewsCount})')])
                      InkWell(
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _tab == i ? AppColors.primary : Colors.transparent, width: 3),
                            ),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _tab == i ? AppColors.primary : AppColors.textSoft,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: _tab == 0
                      ? Text(
                          _plain(p.description ?? p.shortDescription ?? '').isEmpty
                              ? 'Sin descripción.'
                              : _plain(p.description ?? p.shortDescription!),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: (p.description ?? '').isEmpty ? const Color(0xFFAAAAAA) : AppColors.text,
                          ),
                        )
                      : Text(
                          p.reviewsCount == 0 ? 'Aún no hay reseñas.' : 'Valoración media: ${p.rating.toStringAsFixed(1)} de 5.',
                          style: const TextStyle(color: Color(0xFFAAAAAA)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// La descripción viene en HTML del editor de la web.
  static String _plain(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class _SizeBox extends StatelessWidget {
  final String size;
  final bool selected, enabled;
  final VoidCallback onTap;
  const _SizeBox(this.size, {required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    child: Container(
      constraints: const BoxConstraints(minWidth: 44),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.softPrimary : Colors.white,
        border: Border.all(color: selected ? AppColors.primary : const Color(0xFFDDDDDD), width: selected ? 2 : 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          size,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: enabled ? const Color(0xFF333333) : AppColors.strike,
            decoration: enabled ? null : TextDecoration.lineThrough,
          ),
        ),
      ),
    ),
  );
}

class _ColorBox extends StatelessWidget {
  final Stock stock;
  final bool selected, enabled;
  final VoidCallback onTap;
  const _ColorBox(this.stock, {required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: stock.colorLabel ?? stock.color ?? '',
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : .3,
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: stock.swatch ?? AppColors.muted2,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0x22000000)),
            ),
          ),
        ),
      ),
    ),
  );
}
