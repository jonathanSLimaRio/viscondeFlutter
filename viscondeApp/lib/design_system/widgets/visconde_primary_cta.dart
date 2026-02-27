// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../effects/visconde_effects.dart';
import '../tokens/visconde_tokens.dart';

class ViscondePrimaryCta extends StatelessWidget {
  const ViscondePrimaryCta({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    final disabled = onPressed == null;

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: disabled
            ? LinearGradient(
                colors: [
                  colors.primary.withOpacity(0.45),
                  colors.primaryDark.withOpacity(0.45),
                ],
              )
            : context.viscondeGradients.primaryCta,
        borderRadius: BorderRadius.circular(context.viscondeRadii.pill),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.1),
        boxShadow: ViscondeEffects.ctaShadows(context),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(context.viscondeRadii.pill),
        child: button,
      ),
    );
  }
}
