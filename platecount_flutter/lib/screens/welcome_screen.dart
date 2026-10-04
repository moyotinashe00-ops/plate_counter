import 'package:flutter/material.dart';
import '../theme.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const features = [
      (Icons.receipt_long, 'Serve in one tap', 'Big buttons, stock deducted instantly.'),
      (Icons.restaurant, 'Chef controls stock', 'Prep counts, prices, low-stock alerts.'),
      (Icons.payments_outlined, 'Change & credit', 'Money owed to and by customers, kept apart.'),
      (Icons.bar_chart, 'Daily reports', 'Revenue by item, export to CSV.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 40, 24, 24), children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: PC.ink, borderRadius: BorderRadius.circular(99)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 4, backgroundColor: PC.primary),
                    SizedBox(width: 8),
                    Text('PLATECOUNT', style: TextStyle(color: PC.background, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.2)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Text.rich(TextSpan(style: t.displaySmall, children: const [
                TextSpan(text: 'Every plate '),
                TextSpan(text: 'counted.', style: TextStyle(color: PC.primary)),
              ])),
              const SizedBox(height: 16),
              Text('Stock, sales and change for small kitchens, food trucks and vendors.',
                  style: t.titleMedium?.copyWith(color: PC.muted)),
              const SizedBox(height: 32),
              for (final f in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: PC.accent, borderRadius: BorderRadius.circular(12)),
                        child: Icon(f.$1, color: PC.ink, size: 20),
                      ),
                      title: Text(f.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(f.$3),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                child: const Text('Sign in to your kitchen'),
              ),
              const SizedBox(height: 12),
              const Text('The first account created becomes the chef.',
                  textAlign: TextAlign.center, style: TextStyle(color: PC.muted, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
