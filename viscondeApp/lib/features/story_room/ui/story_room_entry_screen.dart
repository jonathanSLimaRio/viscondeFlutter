import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../../story_game/ui/story_game_room_screen.dart';
import 'story_room_screen.dart';

class StoryRoomEntryScreen extends ConsumerWidget {
  const StoryRoomEntryScreen({super.key, required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameEnabled = ref.watch(storyGameRoomEnabledProvider);
    if (!gameEnabled) {
      return StoryRoomScreen(storyId: storyId);
    }

    return StoryGameRoomScreen(storyId: storyId);
  }
}
