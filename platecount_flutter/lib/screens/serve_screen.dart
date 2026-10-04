import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../theme.dart';
import 'home_shell.dart';

class ServeScreen extends StatefulWidget {
  const ServeScreen({super.key});
  @override
  State<ServeScreen> createState() => _ServeScreenState();
}

class _ServeScreenState extends State<ServeScreen> {
  List items = [], sales = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Future.wait([api.get('/food-items'), api.get('/sales', {'from': today(), 'mine': '1'})]);
      setState(() {
        items = (r[0] as List).where((i) => i['active'] == true).toList();
        sales = r[1] as List;
      });
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sell(Map item) async {
    int qty = 1;
    final ref = '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(item['name'], style: Theme.of(ctx).textTheme.headlineSmall),
            Text('${fmtMoney(item['price'])} per ${item['unit']} · ${item['stock']} available', style: const TextStyle(color: PC.muted)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(iconSize: 32, onPressed: qty > 1 ? () => set(() => qty--) : null, icon: const Icon(Icons.remove)),
              SizedBox(width: 90, child: Text('$qty', textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.displaySmall)),
              IconButton.filledTonal(iconSize: 32, onPressed: qty < item['stock'] ? () => set(() => qty++) : null, icon: const Icon(Icons.add)),
            ]),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sell $qty · ${fmtMoney(qty * item['price'])}')),
          ]),
        );
      }),
    );
    if (ok != true) return;
    try {
      await api.post('/sales', {'item_id': item['id'], 'qty': qty, 'client_ref': ref});
      if (mounted) toast(context, 'Sold $qty × ${item['name']}');
      load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = sales.where((s) => s['voided'] != true);
    final total = live.fold<num>(0, (a, s) => a + s['total']);
    return Scaffold(
      appBar: const PageHeader('Serve'),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (items.isEmpty) const EmptyNote('No food on the menu yet. The chef adds items in Stock.'),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [for (final i in items) _tile(i)],
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Text('Your sales today', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(fmtMoney(total), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: PC.primary)),
                ]),
                const SizedBox(height: 8),
                if (sales.isEmpty) const EmptyNote('No sales yet today.'),
                for (final s in sales)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['qty']} × ${s['item_name']}',
                        style: TextStyle(decoration: s['voided'] == true ? TextDecoration.lineThrough : null)),
                    subtitle: Text(DateFormat.Hm().format(DateTime.parse(s['created_at']).toLocal()) +
                        (s['voided'] == true ? ' · Voided' : '')),
                    trailing: Text(fmtMoney(s['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
    );
  }

  Widget _tile(Map i) {
    final soldOut = i['stock'] <= 0;
    final low = !soldOut && i['stock'] <= i['low_stock_threshold'];
    return Material(
      color: soldOut ? PC.border : PC.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: PC.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: soldOut ? null : () => sell(i),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (soldOut || low)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: soldOut ? PC.danger : PC.warning, borderRadius: BorderRadius.circular(99)),
                child: Text(soldOut ? 'Sold out' : 'Low',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: soldOut ? Colors.white : PC.ink)),
              ),
            const Spacer(),
            Text(i['name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
            Text(fmtMoney(i['price']), style: const TextStyle(color: PC.primary, fontWeight: FontWeight.w700)),
            Text('${i['stock']} Available', style: const TextStyle(color: PC.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
