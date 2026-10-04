import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PC {
  static const background = Color(0xFFF7F1E8);
  static const card = Color(0xFFFFFCF8);
  static const ink = Color(0xFF2A211B);
  static const primary = Color(0xFFE0612A);
  static const accent = Color(0xFFF6DEC6);
  static const muted = Color(0xFF7A6A5E);
  static const border = Color(0xFFE6D9C7);
  static const success = Color(0xFF2F8A55);
  static const warning = Color(0xFFE9B23A);
  static const danger = Color(0xFFC8352B);
}

final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
String fmtMoney(num? v) => money.format(v ?? 0);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PC.primary,
      primary: PC.primary,
      surface: PC.background,
      onSurface: PC.ink,
      error: PC.danger,
    ),
    scaffoldBackgroundColor: PC.background,
  );
  final body = GoogleFonts.dmSansTextTheme(base.textTheme).apply(bodyColor: PC.ink, displayColor: PC.ink);
  return base.copyWith(
    textTheme: body.copyWith(
      displaySmall: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800, color: PC.ink, fontSize: 44, height: 0.95),
      headlineSmall: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800, color: PC.ink),
      titleLarge: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, color: PC.ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: PC.background,
      foregroundColor: PC.ink,
      elevation: 0,
      titleTextStyle: GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w800, color: PC.ink),
    ),
    cardTheme: CardThemeData(
      color: PC.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: PC.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PC.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PC.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PC.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PC.border)),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: PC.card, indicatorColor: PC.accent),
  );
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? PC.danger : PC.ink));
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const StatCard(this.label, this.value, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: PC.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color ?? PC.ink, fontSize: 24)),
          ]),
        ),
      );
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: PC.muted))),
      );
}

String today() => DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
