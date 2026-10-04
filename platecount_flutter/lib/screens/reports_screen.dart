import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../theme.dart';
import 'home_shell.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange range = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  Map? r;
  final f = DateFormat('yyyy-MM-dd');
  Map<String, String> get q => {'from': f.format(range.start), 'to': f.format(range.end)};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final res = await api.get('/reports', q);
      setState(() => r = res);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> voidSale(Map s) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void sale'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason for voiding this sale?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 44), backgroundColor: PC.danger),
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Void sale')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.post('/sales/${s['id']}/void', {'reason': reason.text.trim()});
      if (mounted) toast(context, 'Sale voided, stock restored');
      load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> exportCsv() async {
    try {
      final csv = await api.get('/reports.csv', q);
      await Clipboard.setData(ClipboardData(text: csv.toString()));
      if (mounted) toast(context, 'CSV copied to clipboard');
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const PageHeader('Reports'),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(range.start == range.end ? f.format(range.start) : '${f.format(range.start)} → ${f.format(range.end)}'),
                      onPressed: () async {
                        final p = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDateRange: range);
                        if (p != null) {
                          setState(() => range = p);
                          load();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(tooltip: 'Export CSV', onPressed: exportCsv, icon: const Icon(Icons.download)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: StatCard('Total sales', fmtMoney(r!['revenue']), color: PC.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard('Transactions', '${r!['transactions']}')),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text('Change open ${fmtMoney(r!['change_open'])}')),
                  Chip(label: Text('Change paid ${fmtMoney(r!['change_paid'])}')),
                  Chip(label: Text('Credit issued ${fmtMoney(r!['credit_issued'])}')),
                  Chip(label: Text('Credit repaid ${fmtMoney(r!['credit_repaid'])}')),
                ]),
                const SizedBox(height: 20),
                Text('By item', style: t.titleLarge),
                if ((r!['by_item'] as List).isEmpty) const EmptyNote('No sales in this period.'),
                for (final i in r!['by_item'])
                  ListTile(contentPadding: EdgeInsets.zero, title: Text(i['item']), subtitle: Text('Qty sold ${i['qty']}'),
                      trailing: Text(fmtMoney(i['revenue']))),
                const SizedBox(height: 12),
                Text('Staff', style: t.titleLarge),
                for (final c in r!['by_cashier'])
                  ListTile(contentPadding: EdgeInsets.zero, title: Text(c['cashier']), subtitle: Text('${c['transactions']} transactions'),
                      trailing: Text(fmtMoney(c['revenue']))),
                const SizedBox(height: 12),
                Text('Sales', style: t.titleLarge),
                for (final s in r!['sales'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['qty']} × ${s['item_name']}',
                        style: TextStyle(decoration: s['voided'] == true ? TextDecoration.lineThrough : null)),
                    subtitle: Text('${DateFormat('d MMM HH:mm').format(DateTime.parse(s['created_at']).toLocal())} · ${s['cashier_name']}'
                        '${s['voided'] == true ? ' · Voided: ${s['void_reason']}' : ''}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(fmtMoney(s['total'])),
                      if (s['voided'] != true)
                        IconButton(tooltip: 'Void sale', icon: const Icon(Icons.undo, color: PC.danger), onPressed: () => voidSale(s)),
                    ]),
                  ),
              ]),
            ),
    );
  }
}
