import 'package:flutter/material.dart';

import '../../../../design_system/visconde.dart';

class StoryVaultSearchBar extends StatelessWidget {
  const StoryVaultSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onOpenFilters,
    this.hintText = 'Buscar história, tema ou personagem...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onOpenFilters;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    final radii = context.viscondeRadii;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: context.viscondeGradients.glass,
        borderRadius: BorderRadius.circular(radii.xl),
        border: Border.all(color: colors.borderSoft, width: 1.2),
        boxShadow: context.viscondeElevations.card,
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.search_rounded, color: colors.textMuted, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const VerticalDivider(indent: 8, endIndent: 8),
          IconButton(
            onPressed: onOpenFilters,
            tooltip: 'Filtro',
            icon: Icon(Icons.tune_rounded, color: colors.textStrong, size: 28),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
