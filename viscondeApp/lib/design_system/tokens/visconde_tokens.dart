import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class ViscondeColors extends ThemeExtension<ViscondeColors> {
  const ViscondeColors({
    required this.parchment,
    required this.parchmentSoft,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.accent,
    required this.textStrong,
    required this.textMuted,
    required this.borderSoft,
    required this.cardOverlay,
    required this.warning,
  });

  final Color parchment;
  final Color parchmentSoft;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color accent;
  final Color textStrong;
  final Color textMuted;
  final Color borderSoft;
  final Color cardOverlay;
  final Color warning;

  static const fallback = ViscondeColors(
    parchment: Color(0xFFF7EFE3),
    parchmentSoft: Color(0xFFFDF8EF),
    backgroundTop: Color(0xFFF4E9D8),
    backgroundBottom: Color(0xFFEBDCC8),
    primary: Color(0xFF86B774),
    primaryDark: Color(0xFF5F8F56),
    secondary: Color(0xFF74A8C8),
    accent: Color(0xFFF0C776),
    textStrong: Color(0xFF3E281B),
    textMuted: Color(0xFF6B5446),
    borderSoft: Color(0x66FFFFFF),
    cardOverlay: Color(0xCCFFFFFF),
    warning: Color(0xFFD17A5A),
  );

  @override
  ViscondeColors copyWith({
    Color? parchment,
    Color? parchmentSoft,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? primary,
    Color? primaryDark,
    Color? secondary,
    Color? accent,
    Color? textStrong,
    Color? textMuted,
    Color? borderSoft,
    Color? cardOverlay,
    Color? warning,
  }) {
    return ViscondeColors(
      parchment: parchment ?? this.parchment,
      parchmentSoft: parchmentSoft ?? this.parchmentSoft,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      textStrong: textStrong ?? this.textStrong,
      textMuted: textMuted ?? this.textMuted,
      borderSoft: borderSoft ?? this.borderSoft,
      cardOverlay: cardOverlay ?? this.cardOverlay,
      warning: warning ?? this.warning,
    );
  }

  @override
  ViscondeColors lerp(ThemeExtension<ViscondeColors>? other, double t) {
    if (other is! ViscondeColors) {
      return this;
    }

    return ViscondeColors(
      parchment: Color.lerp(parchment, other.parchment, t) ?? parchment,
      parchmentSoft:
          Color.lerp(parchmentSoft, other.parchmentSoft, t) ?? parchmentSoft,
      backgroundTop:
          Color.lerp(backgroundTop, other.backgroundTop, t) ?? backgroundTop,
      backgroundBottom:
          Color.lerp(backgroundBottom, other.backgroundBottom, t) ??
          backgroundBottom,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t) ?? primaryDark,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      textStrong: Color.lerp(textStrong, other.textStrong, t) ?? textStrong,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t) ?? borderSoft,
      cardOverlay: Color.lerp(cardOverlay, other.cardOverlay, t) ?? cardOverlay,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}

@immutable
class ViscondeRadii extends ThemeExtension<ViscondeRadii> {
  const ViscondeRadii({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.pill,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double pill;

  static const fallback = ViscondeRadii(
    xs: 12,
    sm: 16,
    md: 20,
    lg: 26,
    xl: 32,
    pill: 999,
  );

  BorderRadius radius(double value) => BorderRadius.circular(value);

  @override
  ViscondeRadii copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? pill,
  }) {
    return ViscondeRadii(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      pill: pill ?? this.pill,
    );
  }

  @override
  ViscondeRadii lerp(ThemeExtension<ViscondeRadii>? other, double t) {
    if (other is! ViscondeRadii) {
      return this;
    }

    return ViscondeRadii(
      xs: lerpDouble(xs, other.xs, t) ?? xs,
      sm: lerpDouble(sm, other.sm, t) ?? sm,
      md: lerpDouble(md, other.md, t) ?? md,
      lg: lerpDouble(lg, other.lg, t) ?? lg,
      xl: lerpDouble(xl, other.xl, t) ?? xl,
      pill: lerpDouble(pill, other.pill, t) ?? pill,
    );
  }
}

@immutable
class ViscondeGradients extends ThemeExtension<ViscondeGradients> {
  const ViscondeGradients({
    required this.background,
    required this.primaryCta,
    required this.hero,
    required this.pill,
    required this.glass,
  });

  final Gradient background;
  final Gradient primaryCta;
  final Gradient hero;
  final Gradient pill;
  final Gradient glass;

  static const fallback = ViscondeGradients(
    background: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF8EEDC), Color(0xFFF0E4D1), Color(0xFFE7D8C3)],
    ),
    primaryCta: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFB9D99C), Color(0xFF8FBF73), Color(0xFF79AC61)],
    ),
    hero: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xCCFFF8EC), Color(0xA6F4EFE3)],
    ),
    pill: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF8F0), Color(0xFFF2E6D7)],
    ),
    glass: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xCCFFFFFF), Color(0xAAFFF8F0)],
    ),
  );

  @override
  ViscondeGradients copyWith({
    Gradient? background,
    Gradient? primaryCta,
    Gradient? hero,
    Gradient? pill,
    Gradient? glass,
  }) {
    return ViscondeGradients(
      background: background ?? this.background,
      primaryCta: primaryCta ?? this.primaryCta,
      hero: hero ?? this.hero,
      pill: pill ?? this.pill,
      glass: glass ?? this.glass,
    );
  }

  @override
  ViscondeGradients lerp(ThemeExtension<ViscondeGradients>? other, double t) {
    if (other is! ViscondeGradients) {
      return this;
    }

    return t < 0.5 ? this : other;
  }
}

@immutable
class ViscondeElevations extends ThemeExtension<ViscondeElevations> {
  const ViscondeElevations({
    required this.soft,
    required this.card,
    required this.cta,
  });

  final List<BoxShadow> soft;
  final List<BoxShadow> card;
  final List<BoxShadow> cta;

  static const fallback = ViscondeElevations(
    soft: [
      BoxShadow(color: Color(0x1A6B4E3D), blurRadius: 10, offset: Offset(0, 4)),
    ],
    card: [
      BoxShadow(
        color: Color(0x246B4E3D),
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
      BoxShadow(color: Color(0x12FFFFFF), blurRadius: 4, offset: Offset(0, 1)),
    ],
    cta: [
      BoxShadow(color: Color(0x406E9E56), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );

  @override
  ViscondeElevations copyWith({
    List<BoxShadow>? soft,
    List<BoxShadow>? card,
    List<BoxShadow>? cta,
  }) {
    return ViscondeElevations(
      soft: soft ?? this.soft,
      card: card ?? this.card,
      cta: cta ?? this.cta,
    );
  }

  @override
  ViscondeElevations lerp(ThemeExtension<ViscondeElevations>? other, double t) {
    if (other is! ViscondeElevations) {
      return this;
    }

    return t < 0.5 ? this : other;
  }
}

@immutable
class ViscondeSpacing extends ThemeExtension<ViscondeSpacing> {
  const ViscondeSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.section,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double section;

  static const fallback = ViscondeSpacing(
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    section: 28,
  );

  @override
  ViscondeSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? section,
  }) {
    return ViscondeSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      section: section ?? this.section,
    );
  }

  @override
  ViscondeSpacing lerp(ThemeExtension<ViscondeSpacing>? other, double t) {
    if (other is! ViscondeSpacing) {
      return this;
    }

    return ViscondeSpacing(
      xs: lerpDouble(xs, other.xs, t) ?? xs,
      sm: lerpDouble(sm, other.sm, t) ?? sm,
      md: lerpDouble(md, other.md, t) ?? md,
      lg: lerpDouble(lg, other.lg, t) ?? lg,
      xl: lerpDouble(xl, other.xl, t) ?? xl,
      section: lerpDouble(section, other.section, t) ?? section,
    );
  }
}

extension ViscondeThemeTokensX on BuildContext {
  ViscondeColors get viscondeColors =>
      Theme.of(this).extension<ViscondeColors>() ?? ViscondeColors.fallback;

  ViscondeRadii get viscondeRadii =>
      Theme.of(this).extension<ViscondeRadii>() ?? ViscondeRadii.fallback;

  ViscondeGradients get viscondeGradients =>
      Theme.of(this).extension<ViscondeGradients>() ??
      ViscondeGradients.fallback;

  ViscondeElevations get viscondeElevations =>
      Theme.of(this).extension<ViscondeElevations>() ??
      ViscondeElevations.fallback;

  ViscondeSpacing get viscondeSpacing =>
      Theme.of(this).extension<ViscondeSpacing>() ?? ViscondeSpacing.fallback;
}
