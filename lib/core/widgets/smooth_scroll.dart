import 'package:flutter/material.dart';

/// Shared scroll settings tuned for smooth 60fps lists on mid-range Android.
class SmoothScroll {
  SmoothScroll._();

  /// Prefer clamping over bouncing — less stretch work during fling.
  static const ScrollPhysics physics = ClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  static const ScrollPhysics bouncing = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  /// Reasonable cache — enough for smooth fling, not huge memory.
  static const double cacheExtent = 250;
}

/// Lightweight list row shell — avoids Material elevation / shape redraw cost.
class SmoothListTile extends StatelessWidget {
  const SmoothListTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.margin = const EdgeInsets.only(bottom: 8),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? (isDark ? const Color(0xFF161B22) : Colors.white);
    final border = borderColor ?? scheme.outline.withValues(alpha: 0.08);

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
