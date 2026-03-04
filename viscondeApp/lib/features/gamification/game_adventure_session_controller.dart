import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameAdventureSessionState {
  const GameAdventureSessionState({
    this.storyId,
    this.title,
    this.childProfileId,
    this.theme,
    this.biome,
  });

  final String? storyId;
  final String? title;
  final String? childProfileId;
  final String? theme;
  final String? biome;

  bool get hasAdventureName => title != null && title!.trim().isNotEmpty;

  GameAdventureSessionState copyWith({
    String? storyId,
    String? title,
    String? childProfileId,
    String? theme,
    String? biome,
    bool clear = false,
  }) {
    if (clear) {
      return const GameAdventureSessionState();
    }
    return GameAdventureSessionState(
      storyId: storyId ?? this.storyId,
      title: title ?? this.title,
      childProfileId: childProfileId ?? this.childProfileId,
      theme: theme ?? this.theme,
      biome: biome ?? this.biome,
    );
  }
}

class GameAdventureSessionController
    extends StateNotifier<GameAdventureSessionState> {
  GameAdventureSessionController() : super(const GameAdventureSessionState());

  void setFromStory({
    required String storyId,
    required String title,
    String? childProfileId,
    String? theme,
    String? biome,
  }) {
    state = GameAdventureSessionState(
      storyId: storyId,
      title: title.trim(),
      childProfileId: childProfileId,
      theme: theme,
      biome: biome,
    );
  }

  void clear() {
    state = const GameAdventureSessionState();
  }
}

final gameAdventureSessionControllerProvider =
    StateNotifierProvider<
      GameAdventureSessionController,
      GameAdventureSessionState
    >((ref) {
      return GameAdventureSessionController();
    });
