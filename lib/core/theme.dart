import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'style.dart';
import 'app_ui.dart';

class AppTheme {
  static const Color primaryColor = AppUi.brandBlue;
  static const Color accentColor = Color(0xFFFF5722);
  static const Color backgroundColorLight = Color(0xFFF4F7FB);
  static const Color backgroundColorDark = Color(0xFF0E1116);

  /// Platform page transitions — used by GetX `Transition.native`.
  static const pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: accentColor,
      surface: backgroundColorLight,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Open_Sans',
      colorScheme: scheme,
      pageTransitionsTheme: pageTransitionsTheme,
      scaffoldBackgroundColor: backgroundColorLight,
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        titleSpacing: 8,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        titleTextStyle: openSansBold.copyWith(
          fontSize: 17,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUi.radiusMd),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
          ),
          textStyle: openSansSemiBold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: accentColor,
      surface: backgroundColorDark,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Open_Sans',
      colorScheme: scheme,
      pageTransitionsTheme: pageTransitionsTheme,
      scaffoldBackgroundColor: backgroundColorDark,
      textTheme: _textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        titleSpacing: 8,
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
        titleTextStyle: openSansBold.copyWith(
          fontSize: 17,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1F27),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUi.radiusMd),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
          ),
          textStyle: openSansSemiBold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: openSansExtraBold.copyWith(fontSize: 32),
      displayMedium: openSansBold.copyWith(fontSize: 28),
      headlineMedium: openSansBold.copyWith(fontSize: 22),
      titleLarge: openSansBold.copyWith(fontSize: 20),
      titleMedium: openSansSemiBold.copyWith(fontSize: 16),
      bodyLarge: openSansRegular.copyWith(fontSize: 16),
      bodyMedium: openSansRegular.copyWith(fontSize: 14),
      bodySmall: openSansRegular.copyWith(fontSize: 12),
      labelLarge: openSansSemiBold.copyWith(fontSize: 14),
    );
  }
}
