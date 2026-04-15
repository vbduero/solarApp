// ============================================================
// Solar-Grow - Tema y Diseño de la Aplicación
// ============================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores principales de Solar-Grow
class SolarColors {
  // Primarios - Verde naturaleza
  static const Color primary = Color(0xFF2D6A4F);
  static const Color primaryLight = Color(0xFF52B788);
  static const Color primaryDark = Color(0xFF1B4332);

  // Secundarios - Dorado solar
  static const Color secondary = Color(0xFFF4A261);
  static const Color secondaryLight = Color(0xFFFFD166);
  static const Color secondaryDark = Color(0xFFE76F51);

  // Azul cielo
  static const Color skyBlue = Color(0xFF457B9D);
  static const Color skyBlueLight = Color(0xFFA8DADC);

  // Fondos
  static const Color background = Color(0xFFF1FAEE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFE8F4F0);
  static const Color cardBgLight = Color(0xFFF0F7F4);

  // Texto
  static const Color textPrimary = Color(0xFF1D3557);
  static const Color textSecondary = Color(0xFF457B9D);
  static const Color textLight = Color(0xFF8D99AE);

  // Estados
  static const Color success = Color(0xFF2D6A4F);
  static const Color warning = Color(0xFFF4A261);
  static const Color error = Color(0xFFE63946);
  static const Color info = Color(0xFF457B9D);

  // Sensores
  static const Color humidity = Color(0xFF457B9D);
  static const Color temperature = Color(0xFFE76F51);
  static const Color light = Color(0xFFFFD166);
  static const Color battery = Color(0xFF52B788);
}

/// Tema principal de Solar-Grow
class SolarTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: SolarColors.primary,
        secondary: SolarColors.secondary,
        surface: SolarColors.surface,
        error: SolarColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: SolarColors.textPrimary,
      ),
      scaffoldBackgroundColor: SolarColors.background,
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: SolarColors.textPrimary,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: SolarColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: SolarColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: SolarColors.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: SolarColors.textPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: SolarColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          color: SolarColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          color: SolarColors.textSecondary,
        ),
        bodySmall: GoogleFonts.outfit(
          fontSize: 12,
          color: SolarColors.textLight,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: SolarColors.textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: SolarColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: SolarColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SolarColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SolarColors.cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SolarColors.primary, width: 2),
        ),
        hintStyle: GoogleFonts.outfit(
          color: SolarColors.textLight,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: SolarColors.primary,
        unselectedItemColor: SolarColors.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
