import 'package:flutter/material.dart';
import '../../../../design_system/visconde.dart';

class StoryRoomMissionCard extends StatelessWidget {
  const StoryRoomMissionCard({super.key, required this.missionText});

  final String missionText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8C4), // Light parchment look
        borderRadius: context.viscondeRadii.base,
        border: Border.all(color: const Color(0xFFD4B483), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.remove, size: 16, color: Color(0xFF8A6D3B)),
              const SizedBox(width: 8),
              Text(
                'Missão Principal',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF2A5298), // Dark blue text
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.remove, size: 16, color: Color(0xFF8A6D3B)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFD4B483)),
          const SizedBox(height: 8),
          Text(
            missionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}
