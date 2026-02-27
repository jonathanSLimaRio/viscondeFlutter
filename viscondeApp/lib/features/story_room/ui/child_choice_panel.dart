import 'package:flutter/material.dart';

import '../../../design_system/visconde.dart';
import '../models/story_models.dart';

class ChildChoicePanel extends StatelessWidget {
  const ChildChoicePanel({
    super.key,
    required this.options,
    required this.onSelect,
    this.enabled = true,
  });

  final List<StoryChoiceOption> options;
  final ValueChanged<StoryChoiceOption> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ViscondeSectionTitle(
          title: 'Escolha da criança',
          subtitle: 'Toque em uma opção para continuar',
        ),
        const SizedBox(height: 8),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ViscondePrimaryCta(
              onPressed: enabled ? () => onSelect(option) : null,
              label: option.label,
            ),
          ),
        ),
      ],
    );
  }
}
