import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────
///  Design Tokens — MCP Avadi Premium CRM
/// ─────────────────────────────────────────────

class AppColors {
  AppColors._();

  /// Flag set by ThemeService to toggle active colors globally.
  static bool isDarkMode = false;

  // Brand Colors matching the reference UI
  static Color get primary => isDarkMode ? const Color(0xFF1E8268) : const Color(0xFF0F4C3A); // Deep Forest Green
  static Color get primaryLight => isDarkMode ? const Color(0xFF269D80) : const Color(0xFF18664F);
  static Color get primaryDark => isDarkMode ? const Color(0xFF0C382A) : const Color(0xFF093125);
  static Color get gold => const Color(0xFFDCA74D); // Warm Champagne / Gold
  static Color get goldLight => const Color(0xFFEBC173);
  static Color get goldDark => const Color(0xFFB58739);

  // Surfaces
  static Color get background => isDarkMode ? const Color(0xFF0E1311) : const Color(0xFFF9FAFB); // Very light warm neutral
  static Color get surface => isDarkMode ? const Color(0xFF161E1A) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant => isDarkMode ? const Color(0xFF202C26) : const Color(0xFFF3F4F6);

  // Text
  static Color get textPrimary => isDarkMode ? const Color(0xFFF9FAFB) : const Color(0xFF111827); // Deep charcoal
  static Color get textSecondary => isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280); // Muted slate
  static Color get textMuted => isDarkMode ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
  static Color get textOnDark => const Color(0xFFFFFFFF);
  static Color get textOnDarkMuted => isDarkMode ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB);

  // Semantic Pill Colors (from reference)
  static Color get statusBooked => const Color(0xFF10B981); // Emerald Green
  static Color get statusBookedBg => isDarkMode ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
  
  static Color get statusPending => const Color(0xFFF59E0B); // Warm Orange
  static Color get statusPendingBg => isDarkMode ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
  
  static Color get statusUpcoming => const Color(0xFF3B82F6); // Clean Blue
  static Color get statusUpcomingBg => isDarkMode ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
  
  static Color get statusCompleted => const Color(0xFF10B981); // Emerald Green
  static Color get statusCompletedBg => isDarkMode ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
  
  static Color get statusRed => const Color(0xFFEF4444); // Professional Red
  static Color get statusRedBg => isDarkMode ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
  
  static Color get statusPurple => const Color(0xFF8B5CF6); // Elegant Purple
  static Color get statusPurpleBg => isDarkMode ? const Color(0xFF4C1D95) : const Color(0xFFF5F3FF);

  // Utility
  static Color get divider => isDarkMode ? const Color(0xFF2B3A33) : const Color(0xFFE5E7EB); // Subtle neutral border
  static Color get shimmerBase => isDarkMode ? const Color(0xFF202C26) : const Color(0xFFE5E7EB);
  static Color get shimmerHighlight => isDarkMode ? const Color(0xFF2B3A33) : const Color(0xFFF9FAFB);
  static Color get overlay => const Color(0x66000000);
}

class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20; // Exact rounded corners from reference
  static const double xl = 24;
  static const double xxl = 32;
  static const double full = 100;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppShadows {
  AppShadows._();

  // Very subtle, premium shadows as requested
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDarkMode ? 0.2 : 0.03),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDarkMode ? 0.15 : 0.02),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get gold => [
    BoxShadow(
      color: AppColors.gold.withValues(alpha: AppColors.isDarkMode ? 0.15 : 0.30),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get header => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: AppColors.isDarkMode ? 0.4 : 0.20),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get fab => [
    BoxShadow(
      color: AppColors.gold.withValues(alpha: AppColors.isDarkMode ? 0.2 : 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F4C3A),
        brightness: Brightness.light,
        primary: const Color(0xFF0F4C3A),
        secondary: const Color(0xFFDCA74D),
        surface: const Color(0xFFFFFFFF),
      ),
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFF111827),
      displayColor: const Color(0xFF111827),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F4C3A),
        foregroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: const Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Color(0xFF0F4C3A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        labelStyle: GoogleFonts.poppins(
          color: const Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF9CA3AF),
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDCA74D),
          foregroundColor: const Color(0xFFFFFFFF),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F4C3A),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFDCA74D),
        foregroundColor: Color(0xFFFFFFFF),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F4C3A),
        contentTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0E1311),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E8268),
        brightness: Brightness.dark,
        primary: const Color(0xFF1E8268),
        secondary: const Color(0xFFDCA74D),
        surface: const Color(0xFF161E1A),
      ),
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFFF9FAFB),
      displayColor: const Color(0xFFF9FAFB),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF161E1A),
        foregroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: const Color(0xFFF9FAFB),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF161E1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF202C26),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Color(0xFF2B3A33), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Color(0xFF1E8268), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        labelStyle: GoogleFonts.poppins(
          color: const Color(0xFF9CA3AF),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF6B7280),
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDCA74D),
          foregroundColor: const Color(0xFF0E1311),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDCA74D),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: const BorderSide(color: Color(0xFF2B3A33), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFDCA74D),
        foregroundColor: Color(0xFF0E1311),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2B3A33),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E8268),
        contentTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
