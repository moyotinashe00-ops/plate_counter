import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../theme.dart';
import 'home_shell.dart';

class ChangeScreen extends StatefulWidget {
  const ChangeScreen({super.key});
  @override
  State<ChangeScreen> createState() => _ChangeScreenState();
}

class _ChangeScreenState extends State<ChangeScreen> {
  List change = [], credit = [];
  bool allowCredit = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Future.wait([api.get('/change'), api.get('/credit'), api.get('/settings')]);
      setState(() {
        change = r[0];
        credit = r[1];
        allowCredit = r[2]['allow_credit'] == true;
      });
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: const PageHeader('Change & credit'),
          body: Column(children: [
            if (api.isChef)
              SwitchListTile(
                title: const Text('Allow food on credit'),
                subtitle: Text(allowCredit ? 'Enabled' : 'Disabled'),
                value: allowCredit,
                onChanged: (v) async {
                  try {
                    await api.patch('/settings', {'allow_credit': v});
                    setState(() => allowCredit = v);
                  } catch (e) {
                    if (context.mounted) toast(context, e.toString(), error: true);
                  }
                },
              ),
            const TabBar(tabs: [Tab(text: 'We owe customer'), Tab(text: 'Customer owes us')]),
            Expanded(
              child: TabBarView(children: [
                _Ledger(path: '/change', rows: change, open: 'pending', openLabel: 'Pending', doneLabel: 'Given',
                    actionLabel: 'Change given', totalLabel: 'Change still owed', onChanged: load),
                allowCredit || credit.isNotEmpty
                    ? _Ledger(path: '/credit', rows: credit, open: 'outstanding', openLabel: 'Outstanding', doneLabel: 'Repaid',
                        actionLabel: 'Credit repaid', totalLabel: 'Credit outstanding', onChanged: load, canAdd: allowCredit)
                    : const EmptyNote('Credit is turned off by the chef.'),
              ]),
            ),
          ]),
        ),
      );
}

class _Ledger extends StatefulWidget {
  final String path, open, openLabel, doneLabel, actionLabel, totalLabel;
  final List rows;
  final VoidCallback onChanged;
  final bool canAdd;
  const _Ledger({required this.path, required this.rows, required this.open, required this.openLabel, required this.doneLabel,
      required this.actionLabel, required this.totalLabel, required this.onChanged, this.canAdd = true});
  @override
  State<_Ledger> createState() => _LedgerState();
}

class _LedgerState extends State<_Ledger> {
  final ref = TextEditingController(), amount = TextEditingController();

  Future<void> add() async {
    if (ref.text.trim().isEmpty) return toast(context, 'Enter a name or reference', error: true);
    final a = double.tryParse(amount.text);
    if (a == null || a <= 0) return toast(context, 'Enter an amount', error: true);
    try {
      await api.post(widget.path, {'reference': ref.text.trim(), 'amount': a});
      ref.clear();
      amount.clear();
      widget.onChanged();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openTotal = widget.rows.where((r) => r['status'] == widget.open).fold<num>(0, (a, r) => a + r['amount']);
    return ListView(padding: const EdgeInsets.all(16), children: [
      StatCard(widget.totalLabel, fmtMoney(openTotal), color: PC.primary),
      if (widget.canAdd) ...[
        const SizedBox(height: 16),
        Row(children: [
          Expanded(flex: 3, child: TextField(controller: ref, decoration: const InputDecoration(labelText: 'Name or ref #'))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount'))),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: add, icon: const Icon(Icons.add), tooltip: 'Add'),
        ]),
      ],
      const SizedBox(height: 12),
      if (widget.rows.isEmpty) const EmptyNote('Nothing here.'),
      for (final r in widget.rows)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
            child: ListTile(
              title: Text(r['reference'], style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${DateFormat('d MMM, HH:mm').format(DateTime.parse(r['created_at']).toLocal())}'
                  ' · ${r['status'] == widget.open ? widget.openLabel : widget.doneLabel}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(fmtMoney(r['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (r['status'] == widget.open)
                  IconButton(
                    tooltip: widget.actionLabel,
                    icon: const Icon(Icons.check_circle_outline, color: PC.success),
                    onPressed: () async {
                      try {
                        await api.post('${widget.path}/${r['id']}/resolve');
                        if (context.mounted) toast(context, widget.actionLabel);
                        widget.onChanged();
                      } catch (e) {
                        if (context.mounted) toast(context, e.toString(), error: true);
                      }
                    },
                  ),
              ]),
            ),
          ),
        ),
    ]);
  }
}
