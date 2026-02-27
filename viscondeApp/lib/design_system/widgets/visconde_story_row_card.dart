import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';
import 'visconde_pill_chip.dart';

class ViscondeStoryRowCard extends StatelessWidget {
  const ViscondeStoryRowCard({
    super.key,
    required this.title,
    this.badgeLabel,
    this.backgroundAsset,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? badgeLabel;
  final String? backgroundAsset;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.viscondeRadii.lg);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: context.viscondeGradients.hero,
            border: Border.all(color: context.viscondeColors.borderSoft),
            boxShadow: context.viscondeElevations.soft,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                if (backgroundAsset != null)
                  Positioned.fill(
                    child: Image.asset(backgroundAsset!, fit: BoxFit.cover),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withOpacity(0.7),
                          Colors.white.withOpacity(0.25),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (badgeLabel != null && badgeLabel!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ViscondePillChip(label: badgeLabel!),
                              ),
                          ],
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
