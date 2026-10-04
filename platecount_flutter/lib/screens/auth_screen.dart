import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool signup = false, busy = false;
  final email = TextEditingController(), pass = TextEditingController(), name = TextEditingController();

  Future<void> submit() async {
    if (pass.text.length < 6) return toast(context, 'Password must be at least 6 characters', error: true);
    setState(() => busy = true);
    try {
      if (signup) {
        await api.signup(email.text.trim(), pass.text, name.text.trim());
      } else {
        await api.login(email.text.trim(), pass.text);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
              Text(signup ? 'Create account' : 'Welcome back', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('Chef and cashier sign in here.', style: TextStyle(color: PC.muted)),
              const SizedBox(height: 24),
              if (signup) ...[
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Your name')),
                const SizedBox(height: 12),
              ],
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), onSubmitted: (_) => submit()),
              const SizedBox(height: 20),
              FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait…' : signup ? 'Create account' : 'Sign in')),
              TextButton(
                onPressed: () => setState(() => signup = !signup),
                child: Text(signup ? 'Already have an account? Sign in' : 'New here? Create an account'),
              ),
            ]),
          ),
        ),
      );
}
