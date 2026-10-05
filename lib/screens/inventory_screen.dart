import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/api.dart';
import '../services/catalog_state.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Mi inventario')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    for (final p in _items!)
                      ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.published ? 'Publicado' : 'Oculto'} · \$${p.unitPrice.toStringAsFixed(2)}'),
                        trailing: Chip(
                          label: Text('${p.totalStock}'),
                          backgroundColor: p.lowStock ? Colors.red.shade100 : null,
                        ),
                        onTap: () => _edit(p),
                      ),
                  ]),
                ),
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
        Text(widget.product.name, style: Theme.of(context).textTheme.titleMedium),
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
