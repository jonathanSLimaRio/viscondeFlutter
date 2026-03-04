import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';
import 'visconde_glass_card.dart';
import 'visconde_mascot.dart';

enum ViscondeHeroBannerVariant { classic, compactModern }

class ViscondeHeroBanner extends StatelessWidget {
  const ViscondeHeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.assetPath,
    this.height = 170,
    this.showMascot = false,
    this.mascotPose = ViscondeMascotPose.readingBook,
    this.mascotAlignment = Alignment.bottomRight,
    this.mascotSize = 96,
    this.mascotOpacity = 1,
    this.variant = ViscondeHeroBannerVariant.classic,
  });

  final String title;
  final String? subtitle;
  final String? assetPath;
  final double height;
  final bool showMascot;
  final ViscondeMascotPose mascotPose;
  final Alignment mascotAlignment;
  final double mascotSize;
  final double mascotOpacity;
  final ViscondeHeroBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    final isCompact = variant == ViscondeHeroBannerVariant.compactModern;
    final resolvedHeight = isCompact && height == 170 ? 132.0 : height;
    final resolvedMascotSize = isCompact && mascotSize == 96
        ? 72.0
        : mascotSize;
    final textPadding = isCompact
        ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
        : const EdgeInsets.all(16);
    final mascotPadding = isCompact
        ? const EdgeInsets.only(right: 10, bottom: 2)
        : const EdgeInsets.only(right: 12, bottom: 4);

    return ViscondeGlassCard(
      padding: EdgeInsets.zero,
      radius: context.viscondeRadii.xl,
      child: SizedBox(
        height: resolvedHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (assetPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(context.viscondeRadii.xl),
                child: Image.asset(assetPath!, fit: BoxFit.cover),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.viscondeRadii.xl),
                gradient: isCompact
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          colors.parchment.withValues(alpha: 0.74),
                          colors.parchment.withValues(alpha: 0.9),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          colors.parchment.withValues(alpha: 0.82),
                        ],
                      ),
              ),
            ),
            if (showMascot)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: mascotAlignment,
                    child: Padding(
                      padding: mascotPadding,
                      child: ViscondeMascot(
                        pose: mascotPose,
                        size: resolvedMascotSize,
                        glow: true,
                        opacity: mascotOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: textPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          maxLines: isCompact ? 2 : null,
                          overflow: isCompact ? TextOverflow.ellipsis : null,
                        ),
                        if (subtitle case final text? when text.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: isCompact ? 2 : 4),
                            child: Text(
                              text,
                              style: Theme.of(context).textTheme.bodyLarge,
                              maxLines: isCompact ? 2 : null,
                              overflow: isCompact
                                  ? TextOverflow.ellipsis
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
