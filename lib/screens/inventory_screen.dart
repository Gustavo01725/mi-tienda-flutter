import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/api.dart';
import '../services/catalog_state.dart';
import '../services/nav_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gu_scaffold.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

/// Inventario del vendedor/admin. Los cambios van a la API y de ahí a la web.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<Api>().get('/seller/products') as List;
      if (mounted) setState(() => _items = r.map((j) => Product.fromJson(j)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _edit(Product p) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StockSheet(product: p),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return GuScaffold(
      active: AppPage.account,
      onRefresh: _load,
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(15, 24, 15, 16),
            child: Row(children: [
              Icon(LineAwesomeIcons.boxes_solid, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Mi inventario', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        if (_error != null)
          SliverToBoxAdapter(child: GuCard(child: Text(_error!, style: const TextStyle(color: AppColors.danger))))
        else if (_items == null)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
        else if (_items!.isEmpty)
          const SliverToBoxAdapter(child: GuCard(child: EmptyState(icon: LineAwesomeIcons.box_open_solid, text: 'Todavía no tienes productos.')))
        else
          SliverToBoxAdapter(
            child: GuCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < _items!.length; i++) ...[
                  if (i > 0) const Divider(),
                  InkWell(
                    onTap: () => _edit(_items![i]),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(width: 48, height: 48, child: NetImg(_items![i].thumbnail)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_items![i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('${_items![i].published ? 'Publicado' : 'Oculto'} · ${money(_items![i].unitPrice)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted2)),
                          ]),
                        ),
                        Pill('${_items![i].totalStock} uds',
                            color: _items![i].lowStock ? AppColors.danger : AppColors.primary,
                            background: _items![i].lowStock ? AppColors.dangerSoft : AppColors.softPrimary),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ),
      ],
    );
  }

}

class _StockSheet extends StatefulWidget {
  final Product product;
  const _StockSheet({required this.product});
  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  late final Map<int, TextEditingController> _qty = {
    for (final s in widget.product.stocks) s.id: TextEditingController(text: '${s.qty}')
  };
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // Antes un texto no numérico se guardaba como 0: un "1O" dejaba la variante agotada sin avisar.
    final rows = <Map<String, int>>[];
    for (final e in _qty.entries) {
      final q = int.tryParse(e.value.text.trim());
      if (q == null || q < 0) {
        setState(() => _error = 'Cantidad no válida: "${e.value.text}". Usa un número entero (0 o más).');
        return;
      }
      rows.add({'id': e.key, 'qty': q});
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await context.read<Api>().put('/seller/products/${widget.product.id}/stocks', {'stocks': rows});
      if (!mounted) return;
      context.read<CatalogState>().apply(Product.fromJson(r));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Cantidad en stock por variante', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        for (final s in widget.product.stocks)
          Row(children: [
            Expanded(child: Text(s.variant.isEmpty ? 'Único' : s.variant)),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _qty[s.id],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Cant.'),
              ),
            ),
          ]),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Guardar')),
      ]),
    );
  }
}
