import 'package:flutter/material.dart';
import 'style.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color accentColor = Color(0xFFFF5722);
  static const Color backgroundColorLight = Color(0xFFF5F5F5);
  static const Color backgroundColorDark = Color(0xFF121212);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColorLight,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColorLight,
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: openSansBold.copyWith(
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColorDark,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: backgroundColorDark,
      textTheme: _textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        titleTextStyle: openSansBold.copyWith(
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[850],
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: openSansBold.copyWith(
        fontSize: 32,
      ),
      titleLarge: openSansBold.copyWith(
        fontSize: 20,
      ),
      bodyLarge: openSansRegular.copyWith(
        fontSize: 16,
      ),
      bodyMedium: openSansRegular.copyWith(
        fontSize: 14,
      ),
    );
  }
}
