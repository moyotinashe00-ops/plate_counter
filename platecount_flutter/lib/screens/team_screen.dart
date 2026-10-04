import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'home_shell.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List team = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await api.get('/team');
      setState(() => team = r);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const PageHeader('Team'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('New staff sign up on the sign-in page and join as cashiers.', style: TextStyle(color: PC.muted)),
          const SizedBox(height: 12),
          for (final u in team)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: PC.accent, child: Text((u['display_name'] as String).characters.first.toUpperCase())),
                  title: Text(u['display_name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${u['email']} · ${u['role']}'),
                  trailing: u['id'] == api.user?['id']
                      ? null
                      : TextButton(
                          onPressed: () async {
                            final role = u['role'] == 'chef' ? 'cashier' : 'chef';
                            try {
                              await api.post('/team/${u['id']}/role', {'role': role});
                              load();
                            } catch (e) {
                              if (context.mounted) toast(context, e.toString(), error: true);
                            }
                          },
                          child: Text('Make ${u['role'] == 'chef' ? 'cashier' : 'chef'}'),
                        ),
                ),
              ),
            ),
        ]),
      );
}
