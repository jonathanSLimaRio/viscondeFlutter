import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameAdventureSessionState {
  const GameAdventureSessionState({this.storyId, this.title});

  final String? storyId;
  final String? title;

  bool get hasAdventureName => title != null && title!.trim().isNotEmpty;

  GameAdventureSessionState copyWith({
    String? storyId,
    String? title,
    bool clear = false,
  }) {
    if (clear) {
      return const GameAdventureSessionState();
    }
    return GameAdventureSessionState(
      storyId: storyId ?? this.storyId,
      title: title ?? this.title,
    );
  }
}

class GameAdventureSessionController
    extends StateNotifier<GameAdventureSessionState> {
  GameAdventureSessionController() : super(const GameAdventureSessionState());

  void setFromStory({required String storyId, required String title}) {
    state = GameAdventureSessionState(storyId: storyId, title: title.trim());
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
