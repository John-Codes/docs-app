import 'package:flutter/material.dart';

const _paper = Color(0xFFF6F4EE);
const _ink = Color(0xFF232823);
const _sage = Color(0xFF3E7C6B);

ThemeData _base(ColorScheme scheme) {
  final textTheme = Typography.material2021().black.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true, colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme.copyWith(
      bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.55),
      bodySmall: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.45,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      height: 68,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
  );
}

ThemeData lightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _sage,
    brightness: Brightness.light,
  ).copyWith(
    surface: _paper,
    onSurface: _ink,
    outlineVariant: const Color(0xFFE5DFD3),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFFCFBF8),
  );
  return _base(scheme);
}

ThemeData darkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _sage,
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF101412),
    onSurface: const Color(0xFFE8ECE7),
    outlineVariant: const Color(0xFF2A322E),
    surfaceContainerLowest: const Color(0xFF161B18),
    surfaceContainerLow: const Color(0xFF1B211D),
  );
  return _base(scheme);
}
