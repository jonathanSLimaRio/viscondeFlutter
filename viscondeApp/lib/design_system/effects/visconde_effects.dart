import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';

class ViscondeEffects {
  const ViscondeEffects._();

  static List<BoxShadow> cardShadows(BuildContext context) {
    return context.viscondeElevations.card;
  }

  static List<BoxShadow> ctaShadows(BuildContext context) {
    return context.viscondeElevations.cta;
  }

  static Widget blurLayer({
    required Widget child,
    double sigmaX = 8,
    double sigmaY = 8,
    BorderRadius? borderRadius,
  }) {
    if (borderRadius == null) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: child,
      ),
    );
  }
}
