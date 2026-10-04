import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'home_shell.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List items = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await api.get('/food-items');
      setState(() => items = r);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> edit([Map? item]) async {
    final name = TextEditingController(text: item?['name'] ?? '');
    final unit = TextEditingController(text: item?['unit'] ?? 'piece');
    final price = TextEditingController(text: item == null ? '' : '${item['price']}');
    final stock = TextEditingController(text: '0');
    final low = TextEditingController(text: '${item?['low_stock_threshold'] ?? 5}');
    bool active = item?['active'] ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(item == null ? 'Add food' : 'Edit food'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'Chicken')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Sold per'))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (item == null) ...[
                  Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prepared now'))),
                  const SizedBox(width: 10),
                ],
                Expanded(child: TextField(controller: low, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Low-stock alert at'))),
              ]),
              if (item != null)
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('On the menu'), value: active, onChanged: (v) => set(() => active = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              onPressed: () async {
                final p = double.tryParse(price.text);
                if (p == null || p < 0) return toast(ctx, 'Enter a valid price', error: true);
                final body = {
                  'name': name.text.trim(),
                  'unit': unit.text.trim(),
                  'price': p,
                  'low_stock_threshold': int.tryParse(low.text) ?? 5,
                };
                try {
                  if (item == null) {
                    await api.post('/food-items', {...body, 'stock': int.tryParse(stock.text) ?? 0});
                  } else {
                    await api.patch('/food-items/${item['id']}', {...body, 'active': active});
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) toast(ctx, e.toString(), error: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      if (mounted) toast(context, 'Saved');
      load();
    }
  }

  Future<void> adjust(Map item) async {
    String mode = 'prep';
    final qty = TextEditingController(), reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(item['name']),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'prep', label: Text('Prepared more')),
                ButtonSegment(value: 'fix', label: Text('Remove / correct')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => set(() => mode = s.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              onPressed: () async {
                final n = int.tryParse(qty.text);
                if (n == null || n <= 0) return toast(ctx, 'Enter a quantity', error: true);
                try {
                  await api.post('/food-items/${item['id']}/adjust', {
                    'delta': mode == 'prep' ? n : -n,
                    'reason': reason.text.trim().isEmpty ? (mode == 'prep' ? 'Prepared more' : 'Correction') : reason.text.trim(),
                    'is_prep': mode == 'prep',
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) toast(ctx, e.toString(), error: true);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) load();
  }

  @override
  Widget build(BuildContext context) {
    final low = items.where((i) => i['active'] == true && i['stock'] <= i['low_stock_threshold']).toList();
    return Scaffold(
      appBar: const PageHeader('Stock'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: PC.primary, foregroundColor: Colors.white,
        onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Add food'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
          if (low.isNotEmpty)
            Card(
              color: PC.warning.withOpacity(.25),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text('Running low: ${low.map((i) => i['name']).join(', ')}'),
              ),
            ),
          if (items.isEmpty) const EmptyNote('Add your first item, e.g. Chicken, Beef, Sadza.'),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Card(
                child: ListTile(
                  onTap: () => edit(i),
                  title: Text(i['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${fmtMoney(i['price'])} per ${i['unit']} · prepared ${i['prepared_today']}'
                      '${i['active'] == true ? '' : ' · hidden'}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${i['stock']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: i['stock'] <= i['low_stock_threshold'] ? PC.danger : PC.ink)),
                    IconButton(tooltip: 'Add prepared', icon: const Icon(Icons.tune), onPressed: () => adjust(i)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
