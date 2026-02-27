import 'package:flutter/material.dart';

class VaultHeaderStatsModel {
  const VaultHeaderStatsModel({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final int value;
  final IconData? icon;
}

class StoryVaultFilterChipModel {
  const StoryVaultFilterChipModel({
    required this.label,
    required this.valueLabel,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String valueLabel;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
}

class StoryVaultEmptyActions {
  const StoryVaultEmptyActions({
    required this.onCreateStory,
    required this.onHowItWorks,
  });

  final VoidCallback onCreateStory;
  final VoidCallback onHowItWorks;
}
