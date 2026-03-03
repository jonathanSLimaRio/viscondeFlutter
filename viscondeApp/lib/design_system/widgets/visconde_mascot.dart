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
    this.enhanceHighlights = true,
    this.semanticLabel,
  });

  final ViscondeMascotPose pose;
  final double size;
  final double opacity;
  final bool glow;
  final BoxFit fit;
  final bool enhanceHighlights;
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
    final mascotImage = Image.asset(
      resolvePose(pose),
      fit: fit,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
    );

    final enhancedMascot = enhanceHighlights
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              1.06,
              0,
              0,
              0,
              2,
              0,
              1.06,
              0,
              0,
              2,
              0,
              0,
              1.06,
              0,
              2,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.06),
                BlendMode.screen,
              ),
              child: mascotImage,
            ),
          )
        : mascotImage;

    final mascot = Opacity(
      opacity: opacity.clamp(0, 1),
      child: SizedBox(width: size, height: size, child: enhancedMascot),
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
