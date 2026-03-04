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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: options.map((option) {
            final isSelected = selectedOptionId == option.id;
            final votersIds = votesByOption[option.id] ?? [];
            final voters = participants
                .where((p) => votersIds.contains(p.id))
                .toList();

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: enabled ? () => onSelect(option) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8C4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.green
                            : const Color(0xFFD4B483),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11),
                          ),
                          child: Container(
                            height: 100,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2A5298),
                            ),
                            child: Icon(
                              Icons
                                  .auto_awesome, // Placeholder for specific art
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            option.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        if (voters.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 4,
                              children: voters
                                  .map(
                                    (v) => CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.blue.withValues(
                                        alpha: 0.2,
                                      ),
                                      child: Text(
                                        v.displayName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
