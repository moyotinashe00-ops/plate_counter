import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await api.restore();
  runApp(const PlateCountApp());
}

class PlateCountApp extends StatelessWidget {
  const PlateCountApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PlateCount',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: api,
          builder: (_, __) => api.signedIn ? const HomeShell() : const WelcomeScreen(),
        ),
      );
}
