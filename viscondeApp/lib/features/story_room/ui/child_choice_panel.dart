import 'package:flutter/material.dart';

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
        const Text(
          'Escolha da crianca',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton(
              onPressed: enabled ? () => onSelect(option) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(option.label, textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }
}
