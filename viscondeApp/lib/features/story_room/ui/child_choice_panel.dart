import 'package:flutter/material.dart';

import '../../../design_system/visconde.dart';
import '../models/story_models.dart';

class ChildChoicePanel extends StatelessWidget {
  const ChildChoicePanel({
    super.key,
    required this.options,
    required this.onSelect,
    this.enabled = true,
    this.votesByOption = const {},
    this.participants = const [],
    this.selectedOptionId,
  });

  final List<StoryChoiceOption> options;
  final ValueChanged<StoryChoiceOption> onSelect;
  final bool enabled;
  final Map<String, List<String>>
  votesByOption; // optionId -> List of participantIds
  final List<RemoteParticipantModel> participants;
  final String? selectedOptionId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ViscondeSectionTitle(
          title: 'Escolha da aventura',
          subtitle: 'Decidam juntos o que acontece agora',
        ),
        const SizedBox(height: 8),
        ...options.map((option) {
          final isSelected = selectedOptionId == option.id;
          final votersIds = votesByOption[option.id] ?? [];
          final voters = participants
              .where((p) => votersIds.contains(p.id))
              .toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ViscondePrimaryCta(
                  onPressed: enabled ? () => onSelect(option) : null,
                  label: isSelected ? '✓ ${option.label}' : option.label,
                  // We might want a different style if selected,
                  // but staying simple for MVP.
                ),
                if (voters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: Wrap(
                      spacing: 4,
                      children: voters
                          .map(
                            (v) => Tooltip(
                              message: v.displayName,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.blue.withOpacity(0.2),
                                child: Text(
                                  v.displayName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
