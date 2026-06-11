import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color navy     = Color(0xFF0D1B2A);
  static const Color teal     = Color(0xFF0A9396);
  static const Color tealLight= Color(0xFFE9F5F3);
  static const Color tealMid  = Color(0xFF94D2BD);
  static const Color amber    = Color(0xFFEE9B00);
  static const Color red      = Color(0xFFAE2012);
  static const Color green    = Color(0xFF3D9970);

  // Neutrals
  static const Color gray     = Color(0xFF64748B);
  static const Color lightGray= Color(0xFFE2EAF0);
  static const Color offWhite = Color(0xFFF4F8F8);
  static const Color white    = Color(0xFFFFFFFF);

  // Safety score colors
  static Color safetyColor(double score) {
    if (score >= 75) return const Color(0xFF3D9970);
    if (score >= 50) return const Color(0xFFEE9B00);
    return const Color(0xFFAE2012);
  }

  // Mode colors
  static Color modeColor(String mode) {
    switch (mode) {
      case 'metro':  return teal;
      case 'bus':    return amber;
      case 'auto':   return const Color(0xFFE76F51);
      case 'rail':   return const Color(0xFF6D3A9C);
      case 'walk':   return green;
      default:       return gray;
    }
  }
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.amber,
      surface: AppColors.offWhite,
      onPrimary: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.offWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightGray, width: 0.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: -0.3),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.navy),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.navy, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.gray, height: 1.4),
      labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray, letterSpacing: 0.3),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    ),
  );
}
