import 'package:flutter/material.dart';

class CroniaColors {
  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF64748B);
  static const Color line = Color(0xFFE2E8F0);
  static const Color canvas = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF1F5F9);
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  static const LinearGradient appGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFF1F5F9),
      Color(0xFFEFF6FF),
    ],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), primaryDark, primary],
  );
}

ThemeData buildCroniaTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: CroniaColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: CroniaColors.primary,
    secondary: CroniaColors.secondary,
    surface: CroniaColors.surface,
    error: CroniaColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: CroniaColors.canvas,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: CroniaColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.7,
      ),
      headlineMedium: TextStyle(
        color: CroniaColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        color: CroniaColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        color: CroniaColors.ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: CroniaColors.ink),
      bodyMedium: TextStyle(color: CroniaColors.ink),
      bodySmall: TextStyle(color: CroniaColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: CroniaColors.ink,
      titleTextStyle: TextStyle(
        color: CroniaColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: CroniaColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CroniaColors.surfaceSoft,
      selectedColor: CroniaColors.surfaceSoft,
      disabledColor: CroniaColors.surfaceSoft,
      side: const BorderSide(color: CroniaColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
        color: CroniaColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      secondaryLabelStyle: const TextStyle(
        color: CroniaColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CroniaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(color: CroniaColors.muted),
      hintStyle: const TextStyle(color: CroniaColors.muted),
      prefixIconColor: CroniaColors.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: CroniaColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: CroniaColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: CroniaColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: CroniaColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: CroniaColors.danger, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: CroniaColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: CroniaColors.line,
        disabledForegroundColor: CroniaColors.muted,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: CroniaColors.primaryDark,
        side: const BorderSide(color: CroniaColors.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return CroniaColors.muted;
          return CroniaColors.primaryDark;
        }),
        overlayColor: WidgetStateProperty.all(CroniaColors.surfaceSoft),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w800),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(CroniaColors.ink),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return CroniaColors.surfaceSoft;
          return CroniaColors.surfaceSoft;
        }),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: CroniaColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: CroniaColors.surface,
      indicatorColor: CroniaColors.surfaceSoft,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? CroniaColors.primaryDark
              : CroniaColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? CroniaColors.primaryDark
              : CroniaColors.muted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CroniaColors.primary
            : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CroniaColors.primary.withValues(alpha: 0.28)
            : CroniaColors.muted.withValues(alpha: 0.18),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CroniaColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: CroniaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
