import 'package:flutter/material.dart';

/// Palette inspirée des maquettes : dégradé bleu → turquoise (icône),
/// ticket blanc à encoches, accent citron vert, fond gris clair.
class AppColors {
  static const blueDeep = Color(0xFF1D3FD8);
  static const blue = Color(0xFF2563EB);
  static const sky = Color(0xFF1AA0E8);
  static const teal = Color(0xFF0E8C8C);
  static const lime = Color(0xFFD8F35A);
  static const ink = Color(0xFF0B0F1A);
  static const muted = Color(0xFF8A93A6);
  static const background = Color(0xFFE6E9EE);
  static const card = Colors.white;
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFF5A524);
  static const success = Color(0xFF12A150);

  /// Dégradé de l'icône (bleu profond en haut à gauche → turquoise).
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blueDeep, sky, teal],
    stops: [0.0, 0.55, 1.0],
  );

  /// Dégradé « ticket » de la 3e maquette, décliné dans la palette bleue.
  static const ticketGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B5BFF), Color(0xFF22B8F0), Color(0xFF2FD4B4), lime],
    stops: [0.0, 0.45, 0.8, 1.0],
  );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        primary: AppColors.blue,
        secondary: AppColors.lime,
        surface: AppColors.card,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F5F8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          side: const BorderSide(color: AppColors.blue),
          foregroundColor: AppColors.blue,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
