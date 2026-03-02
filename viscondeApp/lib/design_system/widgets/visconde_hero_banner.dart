import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';
import 'visconde_glass_card.dart';
import 'visconde_mascot.dart';

class ViscondeHeroBanner extends StatelessWidget {
  const ViscondeHeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.assetPath,
    this.trailing,
    this.height = 170,
    this.showMascot = false,
    this.mascotPose = ViscondeMascotPose.readingBook,
    this.mascotAlignment = Alignment.bottomRight,
    this.mascotSize = 96,
    this.mascotOpacity = 0.92,
  });

  final String title;
  final String? subtitle;
  final String? assetPath;
  final Widget? trailing;
  final double height;
  final bool showMascot;
  final ViscondeMascotPose mascotPose;
  final Alignment mascotAlignment;
  final double mascotSize;
  final double mascotOpacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    return ViscondeGlassCard(
      padding: EdgeInsets.zero,
      radius: context.viscondeRadii.xl,
      child: SizedBox(
        height: height,
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
                gradient: LinearGradient(
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
                      padding: EdgeInsets.only(
                        right: trailing != null ? 56 : 12,
                        bottom: 4,
                      ),
                      child: ViscondeMascot(
                        pose: mascotPose,
                        size: mascotSize,
                        glow: true,
                        opacity: mascotOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                        ),
                        if (subtitle case final text? when text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              text,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...?(trailing == null ? null : <Widget>[trailing!]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
