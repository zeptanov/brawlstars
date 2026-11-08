import 'package:flutter/material.dart';

class Palette {
  static const Color bg = Color(0xFF05070D);
  static const Color bgSoft = Color(0xFF080C14);
  static const Color surface = Color(0xFF0C1420);
  static const Color surfaceAlt = Color(0xFF111C2B);
  static const Color line = Color(0xFF1D2C3F);
  static const Color accent = Color(0xFF3BE8C8);
  static const Color accentDeep = Color(0xFF159A85);
  static const Color magenta = Color(0xFFFF4E8E);
  static const Color gold = Color(0xFFFFC857);
  static const Color danger = Color(0xFFFF5A5F);
  static const Color text = Color(0xFFE9F1FB);
  static const Color muted = Color(0xFF8698AF);
  static const Color mutedDark = Color(0xFF56677D);

  static const LinearGradient accentGradient = LinearGradient(
    colors: <Color>[Color(0xFF3BE8C8), Color(0xFF39B6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient panelGradient = LinearGradient(
    colors: <Color>[Color(0xE6101A28), Color(0xE60A111B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.bg,
    colorScheme: const ColorScheme.dark(
      primary: Palette.accent,
      onPrimary: Color(0xFF04100E),
      secondary: Palette.magenta,
      onSecondary: Colors.white,
      surface: Palette.surface,
      onSurface: Palette.text,
      error: Palette.danger,
    ),
    textTheme: base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w900,
        letterSpacing: 6,
        color: Palette.text,
        height: 0.95,
      ),
      displayMedium: const TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: Palette.text,
      ),
      headlineMedium: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: Palette.text,
      ),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Palette.text,
      ),
      titleMedium: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Palette.text,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Palette.text,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13.5,
        height: 1.45,
        color: Palette.muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Palette.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A111B),
      hintStyle: const TextStyle(color: Palette.mutedDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.accent, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.surfaceAlt,
      contentTextStyle: const TextStyle(color: Palette.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Palette.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.line),
      ),
      textStyle: const TextStyle(color: Palette.text, fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1),
  );
}
