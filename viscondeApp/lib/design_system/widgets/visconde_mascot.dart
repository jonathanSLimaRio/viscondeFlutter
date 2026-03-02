import 'package:flutter/material.dart';

import '../art/visconde_art_registry.dart';

enum ViscondeMascotPose {
  wavingControllerBook,
  pointingScroll,
  enchantedHearts,
  studyingDesk,
  speakingMic,
  thumbsUpController,
  readingBook,
  readingBookClose,
  observingSpyglass,
  winkingWavingController,
  seriousController,
  potionPalette,
}

class ViscondeMascot extends StatelessWidget {
  const ViscondeMascot({
    super.key,
    required this.pose,
    this.size = 96,
    this.opacity = 1,
    this.glow = false,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final ViscondeMascotPose pose;
  final double size;
  final double opacity;
  final bool glow;
  final BoxFit fit;
  final String? semanticLabel;

  static String resolvePose(ViscondeMascotPose pose) {
    return ViscondeArtRegistry.resolve(_poseToKey(pose));
  }

  static ViscondeArtKey _poseToKey(ViscondeMascotPose pose) {
    switch (pose) {
      case ViscondeMascotPose.wavingControllerBook:
        return ViscondeArtKey.mascotWavingControllerBook;
      case ViscondeMascotPose.pointingScroll:
        return ViscondeArtKey.mascotPointingScroll;
      case ViscondeMascotPose.enchantedHearts:
        return ViscondeArtKey.mascotEnchantedHearts;
      case ViscondeMascotPose.studyingDesk:
        return ViscondeArtKey.mascotStudyingDesk;
      case ViscondeMascotPose.speakingMic:
        return ViscondeArtKey.mascotSpeakingMic;
      case ViscondeMascotPose.thumbsUpController:
        return ViscondeArtKey.mascotThumbsUpController;
      case ViscondeMascotPose.readingBook:
        return ViscondeArtKey.mascotReadingBook;
      case ViscondeMascotPose.readingBookClose:
        return ViscondeArtKey.mascotReadingBookClose;
      case ViscondeMascotPose.observingSpyglass:
        return ViscondeArtKey.mascotObservingSpyglass;
      case ViscondeMascotPose.winkingWavingController:
        return ViscondeArtKey.mascotWinkingWavingController;
      case ViscondeMascotPose.seriousController:
        return ViscondeArtKey.mascotSeriousController;
      case ViscondeMascotPose.potionPalette:
        return ViscondeArtKey.mascotPotionPalette;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mascot = Opacity(
      opacity: opacity.clamp(0, 1),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(resolvePose(pose), fit: fit),
      ),
    );

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Mascote Visconde',
      child: glow
          ? Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size * 0.92,
                  height: size * 0.92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFE69A).withValues(alpha: 0.32),
                        const Color(0xFFFFE69A).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                mascot,
              ],
            )
          : mascot,
    );
  }
}
