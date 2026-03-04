import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';
import '../typography/visconde_typography.dart';

class ViscondeTheme {
  const ViscondeTheme._();

  static ThemeData buildLightTheme() {
    const colors = ViscondeColors.fallback;
    const radii = ViscondeRadii.fallback;
    const gradients = ViscondeGradients.fallback;
    const elevations = ViscondeElevations.fallback;
    const spacing = ViscondeSpacing.fallback;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.light,
      primary: colors.primary,
      secondary: colors.secondary,
      surface: colors.parchmentSoft,
      error: colors.warning,
    );

    final inputRadius = BorderRadius.circular(radii.lg);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: ViscondeTypography.build(),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.parchmentSoft.withValues(alpha: 0.72),
        foregroundColor: colors.textStrong,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 62,
        titleSpacing: 12,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(radii.md),
          ),
        ),
        titleTextStyle: ViscondeTypography.build().titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colors.cardOverlay,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.lg),
          side: BorderSide(color: colors.borderSoft, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.65),
        hintStyle: TextStyle(color: colors.textMuted.withValues(alpha: 0.8)),
        labelStyle: TextStyle(color: colors.textMuted),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colors.primaryDark, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.pill),
          side: BorderSide(color: colors.borderSoft),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.75),
        selectedColor: colors.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: colors.textStrong,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textStrong,
          side: BorderSide(color: colors.borderSoft, width: 1.2),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: Colors.white.withValues(alpha: 0.45),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: IconThemeData(color: colors.textStrong),
      dividerTheme: DividerThemeData(
        color: colors.borderSoft,
        space: spacing.section,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: colors.parchment.withValues(alpha: 0.9),
        indicatorColor: colors.primary.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.primaryDark : colors.textMuted,
            size: selected ? 24 : 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? colors.primaryDark : colors.textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 11,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.pill),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textMuted,
        textColor: colors.textStrong,
        subtitleTextStyle: TextStyle(color: colors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: colors.textStrong,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.sm),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primaryDark,
      ),
      extensions: const [colors, radii, gradients, elevations, spacing],
    );
  }
}
