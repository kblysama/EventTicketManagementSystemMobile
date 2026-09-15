import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class YerinColors {
  static const background = Color(0xFFF5F9F8);
  static const ink = Color(0xFF040F0F);
  static const muted = Color(0xFF57737A);
  static const mint = Color(0xFFC2FCF7);
  static const cyan = Color(0xFFC9FBFF);
  static const slate = Color(0xFF85BDBF);
  static const border = Color(0xFFD9E4E3);
}

ThemeData yerinTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: YerinColors.muted,
    brightness: Brightness.light,
  ).copyWith(
    primary: YerinColors.ink,
    onPrimary: YerinColors.mint,
    surface: Colors.white,
    onSurface: YerinColors.ink,
    secondary: YerinColors.mint,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    colorScheme: scheme,
    scaffoldBackgroundColor: YerinColors.background,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, color: YerinColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: YerinColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: YerinColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: YerinColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: YerinColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: YerinColors.mint,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: YerinColors.border),
  );
}

String money(int value) => NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    ).format(value);
String dateLabel(DateTime? value, {bool time = true}) => value == null
    ? 'Tarih belirtilmedi'
    : DateFormat(
        time ? 'd MMM yyyy · HH:mm' : 'd MMMM yyyy',
        'tr_TR',
      ).format(value);
