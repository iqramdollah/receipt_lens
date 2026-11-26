import 'package:material_ui/material_ui.dart';

import '../shared/glass.dart';

/// The app's look: Manrope type, soft rounded shapes, and the deep green and
/// butter identity. Anything a screen does not style itself inherits from here.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ColorScheme _scheme(Brightness brightness) {
    final seeded = ColorScheme.fromSeed(
      seedColor: Brand.deep,
      brightness: brightness,
    );

    if (brightness == Brightness.light) {
      return seeded.copyWith(
        primary: Brand.deep,
        onPrimary: Brand.butter,
        primaryContainer: Brand.butter,
        onPrimaryContainer: Brand.deep,
        secondary: Brand.forest,
        onSecondary: Brand.butter,
        secondaryContainer: Brand.butter,
        onSecondaryContainer: Brand.deep,
        tertiaryContainer: const Color(0xFFFFE08A),
        onTertiaryContainer: const Color(0xFF3A2D00),
        surface: const Color(0xFFFFF9E6),
        onSurface: const Color(0xFF10211E),
        onSurfaceVariant: const Color(0xFF4A5C57),
        surfaceContainerLowest: const Color(0xFFFFFDF5),
        outlineVariant: const Color(0xFFE9DFB4),
      );
    }

    return seeded.copyWith(
      primary: Brand.butter,
      onPrimary: Brand.deep,
      primaryContainer: const Color(0xFF0F4A41),
      onPrimaryContainer: Brand.butter,
      secondary: const Color(0xFF7CC4AE),
      onSecondary: Brand.deep,
      secondaryContainer: const Color(0xFF0F4A41),
      onSecondaryContainer: Brand.butter,
      tertiaryContainer: const Color(0xFF4A3D0A),
      onTertiaryContainer: Brand.butter,
      surface: const Color(0xFF031A17),
      onSurface: const Color(0xFFF3EBCB),
      onSurfaceVariant: const Color(0xFFB5C2B8),
      surfaceContainerLowest: const Color(0xFF0A2A25),
      outlineVariant: const Color(0xFF24473F),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);

    final base = ThemeData(colorScheme: scheme, fontFamily: 'Manrope');
    final text = base.textTheme;
    final border = scheme.outlineVariant.withValues(alpha: isDark ? 0.8 : 1);
    const stadium = StadiumBorder();

    // Button and chip text styles must come from the text theme, otherwise
    // they would not carry the Manrope font family.
    final buttonText = text.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: stadium,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: stadium,
        side: BorderSide(color: border),
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: stadium,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: stadium,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          textStyle: buttonText,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? scheme.surfaceContainerHighest : Brand.deep,
        actionTextColor: Brand.amber,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: Brand.butter,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
    );
  }
}