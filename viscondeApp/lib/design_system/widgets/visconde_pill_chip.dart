import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';

class ViscondePillChip extends StatelessWidget {
  const ViscondePillChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Widget? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: selected
            ? context.viscondeGradients.primaryCta
            : context.viscondeGradients.pill,
        borderRadius: BorderRadius.circular(context.viscondeRadii.pill),
        border: Border.all(
          color: selected
              ? colors.primaryDark.withValues(alpha: 0.4)
              : colors.borderSoft,
        ),
        boxShadow: context.viscondeElevations.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : colors.textStrong,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.viscondeRadii.pill),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
