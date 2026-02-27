import 'package:flutter/material.dart';

import '../effects/visconde_effects.dart';
import '../tokens/visconde_tokens.dart';

class ViscondeGlassCard extends StatelessWidget {
  const ViscondeGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radii = context.viscondeRadii;
    final borderRadius = BorderRadius.circular(radius ?? radii.lg);

    final content = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient ?? context.viscondeGradients.glass,
        borderRadius: borderRadius,
        border: Border.all(
          color: context.viscondeColors.borderSoft,
          width: 1.2,
        ),
        boxShadow: ViscondeEffects.cardShadows(context),
      ),
      child: child,
    );

    final interactive = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: content,
            ),
          );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ViscondeEffects.blurLayer(
        sigmaX: 10,
        sigmaY: 10,
        borderRadius: borderRadius,
        child: interactive,
      ),
    );
  }
}
