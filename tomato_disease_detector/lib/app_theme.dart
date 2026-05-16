import 'package:flutter/material.dart';

class AgroColors {
  static const ink = Color(0xFF17231E);
  static const muted = Color(0xFF66736D);
  static const field = Color(0xFF0E8F5A);
  static const leaf = Color(0xFF26B77A);
  static const moss = Color(0xFFDDE9D8);
  static const sand = Color(0xFFF6F2E8);
  static const clay = Color(0xFFB66A3C);
  static const sky = Color(0xFFE9F6F1);
  static const danger = Color(0xFFC84C3A);
  static const warning = Color(0xFFE6A93B);
  static const surface = Color(0xFFFBFCF8);
}

ThemeData buildAgroTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AgroColors.field,
    primary: AgroColors.field,
    secondary: AgroColors.clay,
    surface: AgroColors.surface,
    error: AgroColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AgroColors.surface,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 34, height: 1.08, fontWeight: FontWeight.w700, color: AgroColors.ink),
      headlineMedium: TextStyle(fontSize: 26, height: 1.14, fontWeight: FontWeight.w700, color: AgroColors.ink),
      titleLarge: TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w700, color: AgroColors.ink),
      titleMedium: TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w700, color: AgroColors.ink),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: AgroColors.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: AgroColors.muted),
      labelLarge: TextStyle(fontSize: 14, height: 1.2, fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: AgroColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AgroColors.ink,
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AgroColors.ink),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AgroColors.ink.withValues(alpha: 0.07)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AgroColors.field,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AgroColors.ink,
        minimumSize: const Size(48, 52),
        side: BorderSide(color: AgroColors.ink.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: child,
      ),
    );
  }
}
