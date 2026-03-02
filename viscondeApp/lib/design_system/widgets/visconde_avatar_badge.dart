import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';

class ViscondeAvatarBadge extends StatelessWidget {
  const ViscondeAvatarBadge({
    super.key,
    required this.imageAsset,
    this.size = 52,
    this.badge,
  });

  final String imageAsset;
  final double size;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 2,
                ),
                boxShadow: context.viscondeElevations.soft,
              ),
              child: ClipOval(
                child: Image.asset(imageAsset, fit: BoxFit.cover),
              ),
            ),
          ),
          if (badge != null) Positioned(right: -4, bottom: -4, child: badge!),
        ],
      ),
    );
  }
}
