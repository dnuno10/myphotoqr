import 'package:flutter/material.dart';

import '../shared/ui/app_tokens.dart';

class AppTheme {
  static const Color brandPrimary = Color(0xFF111111);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.light,
        surface: AppTokens.surface,
      ),
    );

    final textTheme = base.textTheme.copyWith(
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyMedium: const TextStyle(fontWeight: FontWeight.w500),
    );

    final cs = base.colorScheme.copyWith(
      primary: brandPrimary,
      secondary: brandPrimary,
      surface: AppTokens.surface,
      onSurface: AppTokens.ink,
    );

    return base.copyWith(
      colorScheme: cs,
      dividerColor: AppTokens.border,
      scaffoldBackgroundColor: AppTokens.bg,
      textTheme: textTheme.apply(
        fontFamily: 'Arial',
        bodyColor: AppTokens.ink,
        displayColor: AppTokens.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppTokens.ink,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: AppTokens.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111116),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppTokens.ink.withOpacity(0.24),
        ),
        labelStyle: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppTokens.ink.withOpacity(0.24),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: AppTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: AppTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(color: cs.primary, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFF04438)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFF04438), width: 1.3),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.border),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.ink,
          side: const BorderSide(color: AppTokens.border),
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppTokens.ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF3F4F7),
        selectedColor: cs.primary.withOpacity(0.12),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        side: const BorderSide(color: AppTokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
    );
  }

  // Mantener login intacto (legacy).
  static ThemeData get login {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C3AED),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      colorScheme: colorScheme.copyWith(
        primary: const Color(0xFF7C3AED),
        secondary: const Color(0xFF7C3AED),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F5F2),
    );
  }
}
