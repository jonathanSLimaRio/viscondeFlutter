import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_adventure_session_controller.dart';

class GameBlankScreen extends ConsumerWidget {
  const GameBlankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventureState = ref.watch(gameAdventureSessionControllerProvider);
    final title = adventureState.title?.trim();
    final label = (title == null || title.isEmpty)
        ? 'Nenhuma aventura criada'
        : title;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
