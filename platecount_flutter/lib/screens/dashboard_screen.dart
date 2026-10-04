import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'home_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map? d;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await api.get('/dashboard', {'from': today()});
      setState(() => d = r);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const PageHeader('Today'),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                StatCard('Revenue today', fmtMoney(d!['revenue']), color: PC.primary),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: StatCard('Change owed', fmtMoney(d!['change_owed']))),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard('Credit owed to us', fmtMoney(d!['credit_owed']))),
                ]),
                const SizedBox(height: 24),
                Text('Sales by item', style: t.titleLarge),
                if ((d!['by_item'] as List).isEmpty) const EmptyNote('No sales yet today.'),
                for (final i in d!['by_item'])
                  ListTile(contentPadding: EdgeInsets.zero, title: Text(i['item']), subtitle: Text('${i['qty']} Sold'),
                      trailing: Text(fmtMoney(i['revenue']), style: const TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(height: 16),
                Text('Stock remaining', style: t.titleLarge),
                for (final i in d!['items'])
                  if (i['active'] == true)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i['name']),
                      subtitle: LinearProgressIndicator(
                        value: i['prepared_today'] > 0 ? (i['stock'] / i['prepared_today']).clamp(0, 1).toDouble() : 0,
                        color: i['stock'] <= i['low_stock_threshold'] ? PC.danger : PC.success,
                        backgroundColor: PC.border,
                      ),
                      trailing: Text('${i['stock']} / ${i['prepared_today']} Prepared'),
                    ),
                const SizedBox(height: 16),
                Text('Cashier activity', style: t.titleLarge),
                for (final c in d!['by_cashier'])
                  ListTile(contentPadding: EdgeInsets.zero, title: Text(c['cashier']), subtitle: Text('${c['transactions']} sales'),
                      trailing: Text(fmtMoney(c['revenue']), style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
    );
  }
}
