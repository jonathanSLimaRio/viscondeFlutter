import 'package:flutter/material.dart';

class ViscondeTypography {
  const ViscondeTypography._();

  static TextTheme build() {
    const base = TextStyle(
      fontFamily: 'sans-serif',
      color: Color(0xFF3E281B),
      height: 1.2,
    );

    return const TextTheme(
      displayLarge: base,
      displayMedium: base,
      displaySmall: base,
      headlineLarge: base,
      headlineMedium: base,
      headlineSmall: base,
      titleLarge: base,
      titleMedium: base,
      titleSmall: base,
      bodyLarge: base,
      bodyMedium: base,
      bodySmall: base,
      labelLarge: base,
      labelMedium: base,
      labelSmall: base,
    ).copyWith(
      headlineLarge: base.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineMedium: base.copyWith(fontSize: 25, fontWeight: FontWeight.w800),
      headlineSmall: base.copyWith(fontSize: 21, fontWeight: FontWeight.w800),
      titleLarge: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      bodyLarge: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF5A4132),
      ),
      bodyMedium: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF6B5446),
      ),
      bodySmall: base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF7A6356),
      ),
      labelLarge: base.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
      labelMedium: base.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
      labelSmall: base.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
    );
  }
}
