import 'package:flutter/material.dart';

class AppTheme {
  static const Color radarTeal = Color(0xFF0D9488);
  static const Color pulseMint = Color(0xFF14B8A6);
  static const Color expiryAmber = Color(0xFFF59E0B);
  static const Color eventIndigo = Color(0xFF6366F1);
  static const Color ghostViolet = Color(0xFF8B5CF6);
  static const Color darkCanvas = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF131C31);
  static const Color darkCard = Color(0xFF1B2642);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: radarTeal,
      brightness: Brightness.dark,
      primary: pulseMint,
      secondary: eventIndigo,
      tertiary: expiryAmber,
      surface: darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: Color(0xFFF8FAFC),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF283558)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: pulseMint.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? pulseMint : const Color(0xFF94A3B8),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF283558)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF283558)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: pulseMint, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: pulseMint.withValues(alpha: 0.22),
        side: const BorderSide(color: Color(0xFF283558)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: radarTeal,
      brightness: Brightness.light,
      primary: radarTeal,
      secondary: eventIndigo,
      tertiary: expiryAmber,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    );
  }
}
