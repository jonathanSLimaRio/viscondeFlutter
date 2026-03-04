import 'package:flutter/material.dart';

import '../design_system/art/visconde_art_registry.dart';

class AvatarPresetOption {
  const AvatarPresetOption({
    required this.key,
    required this.label,
    required this.parentVariants,
    required this.childVariants,
  });

  final String key;
  final String label;
  final List<ViscondeArtKey> parentVariants;
  final List<ViscondeArtKey> childVariants;
}

class AvatarAccentOption {
  const AvatarAccentOption({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

const List<AvatarPresetOption> avatarPresetOptions = <AvatarPresetOption>[
  AvatarPresetOption(
    key: 'guardian',
    label: 'Guardião',
    parentVariants: <ViscondeArtKey>[
      ViscondeArtKey.avatarParent,
      ViscondeArtKey.mascotSeriousController,
      ViscondeArtKey.mascotWavingControllerBook,
    ],
    childVariants: <ViscondeArtKey>[
      ViscondeArtKey.avatarChild,
      ViscondeArtKey.mascotReadingBookClose,
      ViscondeArtKey.mascotThumbsUpController,
    ],
  ),
  AvatarPresetOption(
    key: 'storyteller',
    label: 'Contador',
    parentVariants: <ViscondeArtKey>[
      ViscondeArtKey.mascotPointingScroll,
      ViscondeArtKey.mascotReadingBook,
      ViscondeArtKey.mascotSpeakingMic,
    ],
    childVariants: <ViscondeArtKey>[
      ViscondeArtKey.mascotReadingBookClose,
      ViscondeArtKey.mascotWinkingWavingController,
      ViscondeArtKey.mascotEnchantedHearts,
    ],
  ),
  AvatarPresetOption(
    key: 'explorer',
    label: 'Explorador',
    parentVariants: <ViscondeArtKey>[
      ViscondeArtKey.mascotObservingSpyglass,
      ViscondeArtKey.mascotPotionPalette,
      ViscondeArtKey.mascotThumbsUpController,
    ],
    childVariants: <ViscondeArtKey>[
      ViscondeArtKey.mascotObservingSpyglass,
      ViscondeArtKey.mascotPotionPalette,
      ViscondeArtKey.mascotWinkingWavingController,
    ],
  ),
];

const List<AvatarAccentOption> avatarAccentOptions = <AvatarAccentOption>[
  AvatarAccentOption(key: 'amber', label: 'Âmbar', color: Color(0xFFFFC107)),
  AvatarAccentOption(
    key: 'emerald',
    label: 'Esmeralda',
    color: Color(0xFF10B981),
  ),
  AvatarAccentOption(key: 'sky', label: 'Céu', color: Color(0xFF0EA5E9)),
];

AvatarPresetOption _presetOrDefault(String? key) {
  for (final preset in avatarPresetOptions) {
    if (preset.key == key) {
      return preset;
    }
  }
  return avatarPresetOptions.first;
}

int normalizeAvatarVariant(int? raw) {
  final value = raw ?? 1;
  if (value < 1) {
    return 1;
  }
  if (value > 3) {
    return 3;
  }
  return value;
}

String resolveAvatarAsset({
  required bool isParent,
  String? avatarPresetKey,
  int? avatarVariant,
}) {
  final preset = _presetOrDefault(avatarPresetKey);
  final variants = isParent ? preset.parentVariants : preset.childVariants;
  final normalizedVariant = normalizeAvatarVariant(avatarVariant);
  final index = normalizedVariant - 1;
  final selected = index < variants.length ? variants[index] : variants.first;
  return ViscondeArtRegistry.resolve(selected);
}

Color resolveAvatarAccentColor(String? key) {
  for (final accent in avatarAccentOptions) {
    if (accent.key == key) {
      return accent.color;
    }
  }
  return avatarAccentOptions.first.color;
}
