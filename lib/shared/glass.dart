import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

/// Brand colours, shared with the app icon.
abstract final class Brand {
  static const deep = Color(0xFF0B5F59);
  static const teal = Color(0xFF0F766E);
  static const bright = Color(0xFF14B8A6);
  static const amber = Color(0xFFF59E0B);
}

/// The teal gradient behind the top of a screen. It fades into the normal page
/// colour, so everything lower down sits on a plain, readable surface.
class BrandHeaderBackground extends StatelessWidget {
  const BrandHeaderBackground({super.key, this.height = 400});

  final double height;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Brand.deep, Brand.teal, surface],
                  stops: const [0.0, 0.78, 1.0],
                ),
              ),
            ),
          ),
          // Soft coloured glows: glass needs something colourful behind it.
          // If text on the glass looks too low-contrast, lower these alphas.
          Positioned(
            top: -70,
            right: -60,
            width: 280,
            height: 280,
            child: _Glow(Brand.amber.withValues(alpha: 0.40)),
          ),
          Positioned(
            top: 130,
            left: -110,
            width: 300,
            height: 300,
            child: _Glow(Brand.bright.withValues(alpha: 0.28)),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// A frosted-glass panel for use over [BrandHeaderBackground].
///
/// Its content defaults to white text and icons. Use it on a handful of hero
/// surfaces, never inside a long scrolling list, because the blur is costly.
/// With the system's high-contrast setting on, it becomes a solid panel.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blur = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final solid = MediaQuery.highContrastOf(context);
    final shape = BorderRadius.circular(radius);

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: solid ? Brand.deep : null,
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.24),
                  Colors.white.withValues(alpha: 0.10),
                ],
              ),
        border: Border.all(
          color: Colors.white.withValues(alpha: solid ? 0.6 : 0.30),
        ),
      ),
      child: Padding(
        padding: padding,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white),
            child: child,
          ),
        ),
      ),
    );

    if (solid) return ClipRRect(borderRadius: shape, child: panel);

    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: panel,
      ),
    );
  }
}
