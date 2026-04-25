import 'package:flutter/material.dart';

/// Caliana — light theme.
/// Off-white background, soft blue primary, coral reserved for the mic + her
/// signature alarm moments. Everything rounded 16–20, soft shadows only.
class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFF7F8FA);       // off-white
  static const Color backgroundElevated = Color(0xFFFFFFFF); // pure white card
  static const Color backgroundDeep = Color(0xFFEFF1F5);

  // Glass / surface
  static const Color surfaceGlass = Color(0xFFFFFFFF);
  static const Color surfaceGlassStrong = Color(0xFFFFFFFF);
  static const Color surfaceBorder = Color(0xFFE5E7EB);

  // Primary — soft blue
  static const Color primary = Color(0xFF2F6BFF);
  static const Color primarySoft = Color(0xFFE8EFFF);
  static const Color primaryGlow = Color(0x332F6BFF);
  static const Color primaryDeep = Color(0xFF1F4FE0);

  // Accent — coral (mic + alarm only)
  static const Color accent = Color(0xFFFF5A5F);
  static const Color accentSoft = Color(0xFFFFE8E9);
  static const Color accentGlow = Color(0x33FF5A5F);

  // Subtle aurora hints (kept for back-compat with widgets that import them)
  static const Color auroraA = Color(0xFFE8EFFF);
  static const Color auroraB = Color(0xFFFFE8E9);
  static const Color auroraC = Color(0xFFF7F8FA);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFCBD2DA);

  // States
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFFF5A5F);

  // Macro colors — readable on light
  static const Color macroProtein = Color(0xFFFF5A5F); // coral
  static const Color macroCarbs = Color(0xFFF59E0B);   // amber
  static const Color macroFat = Color(0xFF10B981);     // green

  // Compatibility shims
  static const Color primaryLight = primary;
  static const Color primaryMuted = primaryGlow;
  static const Color surface = backgroundElevated;
  static const Color border = surfaceBorder;
  static const Color borderLight = Color(0xFFEFF1F5);
  static const Color shadow = Color(0x1A0F172A);
  static const Color star = warning;
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          surface: AppColors.background,
          onSurface: AppColors.textPrimary,
        ),
        fontFamily: 'SF Pro Display',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: AppColors.textPrimary),
          displayMedium: TextStyle(color: AppColors.textPrimary),
          displaySmall: TextStyle(color: AppColors.textPrimary),
          headlineLarge: TextStyle(color: AppColors.textPrimary),
          headlineMedium: TextStyle(color: AppColors.textPrimary),
          headlineSmall: TextStyle(color: AppColors.textPrimary),
          titleLarge: TextStyle(color: AppColors.textPrimary),
          titleMedium: TextStyle(color: AppColors.textPrimary),
          titleSmall: TextStyle(color: AppColors.textPrimary),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          bodySmall: TextStyle(color: AppColors.textSecondary),
          labelLarge: TextStyle(color: AppColors.textPrimary),
          labelMedium: TextStyle(color: AppColors.textSecondary),
          labelSmall: TextStyle(color: AppColors.textHint),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        dividerTheme: const DividerThemeData(
          color: AppColors.surfaceBorder,
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

/// Card decorations for the light theme.
/// Soft shadows only — no heavy gradients, no glass blur on dark.
class GlassDecoration {
  /// Standard white card with subtle shadow + 1px border.
  static BoxDecoration card({double opacity = 1.0, double radius = 18}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.surfaceBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Caliana's chat bubble — light blue tint, blue border.
  static BoxDecoration coralCard({double opacity = 1.0, double radius = 18}) {
    return BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.18),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Pill / chip — small floating element.
  static BoxDecoration pill({double opacity = 1.0}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(50),
      border: Border.all(color: AppColors.surfaceBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// The mic FAB — coral gradient, soft glow.
  static BoxDecoration coralFab() {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF7A6B), Color(0xFFFF5A5F), Color(0xFFE94A6F)],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.40),
          blurRadius: 22,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Blue gradient — used for Fix My Day, primary CTAs.
  static BoxDecoration bluePrimary({double radius = 16}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF), Color(0xFF1F4FE0)],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.30),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Header gradient — kept for back-compat.
  static BoxDecoration header() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.auroraA, AppColors.auroraC],
      ),
    );
  }
}
