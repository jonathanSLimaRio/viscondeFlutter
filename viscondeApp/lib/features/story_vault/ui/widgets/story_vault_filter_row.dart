import 'package:flutter/material.dart';

import '../../../../design_system/visconde.dart';
import 'story_vault_ui_models.dart';

class StoryVaultFilterRow extends StatelessWidget {
  const StoryVaultFilterRow({super.key, required this.items});

  final List<StoryVaultFilterChipModel> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final label = '${item.label} · ${item.valueLabel}';

          return ViscondePillChip(
            label: label,
            selected: item.selected,
            icon: item.icon == null ? null : Icon(item.icon, size: 18),
            onTap: item.onTap,
          );
        },
      ),
    );
  }
}
