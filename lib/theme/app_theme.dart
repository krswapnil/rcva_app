import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandRed = Color(0xFF990203);
  static const Color bg = Color(0xFFF7F7F8);

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(seedColor: brandRed);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Montserrat',
      colorScheme: cs,
      scaffoldBackgroundColor: bg,

      appBarTheme: const AppBarTheme(
        backgroundColor: brandRed,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandRed, width: 1.2),
        ),
        labelStyle: const TextStyle(fontFamily: 'Montserrat'),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48), // ✅ FIX
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48), // ✅ FIX
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: brandRed),
          foregroundColor: brandRed,
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandRed,
          textStyle: const TextStyle(fontFamily: 'Montserrat'),
        ),
      ),

      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),

      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
      ),
    );
  }
}
