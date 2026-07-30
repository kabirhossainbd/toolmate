import 'package:flutter/material.dart';

/// Shared visual tokens for Toolmate — gradients, radii, feature accents.
class AppUi {
  AppUi._();

  static const double radiusLg = 24;
  static const double radiusMd = 16;
  static const double radiusSm = 12;

  static const Color brandBlue = Color(0xFF1E88E5);
  static const Color brandDeep = Color(0xFF1565C0);
  static const Color brandPurple = Color(0xFF7B1FA2);
  static const Color brandTeal = Color(0xFF00838F);
  static const Color brandOrange = Color(0xFFFF6D00);
  static const Color brandPink = Color(0xFFE91E63);

  static const LinearGradient brandHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandDeep, brandPurple, brandTeal],
  );

  static LinearGradient pageBackground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        scheme.primaryContainer.withValues(alpha: 0.55),
        scheme.surface,
        scheme.secondaryContainer.withValues(alpha: 0.35),
      ],
    );
  }

  static LinearGradient accentGradient(Color color) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          color,
          Color.lerp(color, Colors.black, 0.12)!,
        ],
      );

  static List<BoxShadow> softGlow(Color color, {double opacity = 0.28}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  /// Soft page shell used across feature screens.
  static Widget gradientScaffold({
    required BuildContext context,
    required PreferredSizeWidget? appBar,
    required Widget body,
    Widget? floatingActionButton,
  }) {
    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: pageBackground(context)),
        child: body,
      ),
    );
  }
}

class FeatureAccent {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const FeatureAccent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
