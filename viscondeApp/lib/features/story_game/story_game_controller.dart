import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/ux_analytics.dart';
import '../story_room/models/story_models.dart';
import '../story_room/story_room_controller.dart';

class StoryGameUiState {
  const StoryGameUiState({
    this.selectedParentActionKey = 'explore_path',
    this.optionalNarrationText = '',
  });

  final String selectedParentActionKey;
  final String optionalNarrationText;

  StoryGameUiState copyWith({
    String? selectedParentActionKey,
    String? optionalNarrationText,
  }) {
    return StoryGameUiState(
      selectedParentActionKey:
          selectedParentActionKey ?? this.selectedParentActionKey,
      optionalNarrationText:
          optionalNarrationText ?? this.optionalNarrationText,
    );
  }
}

class StoryGameController extends StateNotifier<StoryGameUiState> {
  StoryGameController(this._ref) : super(const StoryGameUiState());

  final Ref _ref;

  static const List<StoryGameActionModel> parentActions =
      <StoryGameActionModel>[
        StoryGameActionModel(
          key: 'explore_path',
          label: 'Explorar o próximo caminho',
          iconKey: 'trail',
        ),
        StoryGameActionModel(
          key: 'help_friend',
          label: 'Ajudar um amigo no mapa',
          iconKey: 'friend',
        ),
        StoryGameActionModel(
          key: 'creative_plan',
          label: 'Tentar um plano criativo',
          iconKey: 'idea',
        ),
      ];

  void selectParentAction(String key) {
    state = state.copyWith(selectedParentActionKey: key);
  }

  void updateOptionalNarrationText(String value) {
    state = state.copyWith(optionalNarrationText: value);
  }

  StoryGameActionModel currentParentAction() {
    return parentActions.firstWhere(
      (action) => action.key == state.selectedParentActionKey,
      orElse: () => parentActions.first,
    );
  }

  Future<void> submitParentStep(StorySessionModel story) async {
    final action = currentParentAction();
    final narratorText = state.optionalNarrationText.trim().isNotEmpty
        ? state.optionalNarrationText.trim()
        : action.label;
    final nextStep = story.currentStepIndex + 1;
    final beforeCount = story.steps.length;

    UxAnalytics.log(
      'story_game_action_selected',
      params: <String, Object?>{
        'source': 'story_game_room_screen',
        'flow': 'game_room',
        'story_id': story.id,
        'step': nextStep,
        'mode': story.currentMode.name,
        'action_key': action.key,
        'action_label': action.label,
      },
    );

    await _ref
        .read(storyRoomControllerProvider.notifier)
        .addNarrationStep(
          narratorText: narratorText,
          gameNodeIndex: nextStep,
          gameAction: action,
        );

    final stateAfter = _ref.read(storyRoomControllerProvider);
    final savedCount = stateAfter.session?.steps.length ?? beforeCount;

    if (savedCount > beforeCount) {
      UxAnalytics.log(
        'story_game_step_saved',
        params: <String, Object?>{
          'source': 'story_game_room_screen',
          'flow': 'game_room',
          'story_id': story.id,
          'step': nextStep,
          'node': nextStep,
          'mode': story.currentMode.name,
          'pending_count': stateAfter.pendingCount,
        },
      );
      state = state.copyWith(optionalNarrationText: '');
      return;
    }

    UxAnalytics.log(
      'story_game_step_failed',
      params: <String, Object?>{
        'source': 'story_game_room_screen',
        'flow': 'game_room',
        'story_id': story.id,
        'step': nextStep,
        'node': nextStep,
        'mode': story.currentMode.name,
        'error_kind': stateAfter.error == null ? 'unknown' : 'submit_error',
      },
    );
  }

  Future<void> submitChildChoice(
    StorySessionModel story,
    StoryChoiceOption option,
  ) async {
    final nextStep = story.currentStepIndex + 1;
    final beforeCount = story.steps.length;

    UxAnalytics.log(
      'story_game_action_selected',
      params: <String, Object?>{
        'source': 'story_game_room_screen',
        'flow': 'game_room',
        'story_id': story.id,
        'step': nextStep,
        'mode': story.currentMode.name,
        'action_key': option.id,
        'action_label': option.label,
      },
    );

    await _ref
        .read(storyRoomControllerProvider.notifier)
        .addChildChoiceStep(
          selectedOptionLabel: option.label,
          selectedOptionId: option.id,
          gameNodeIndex: nextStep,
          gameAction: StoryGameActionModel(
            key: option.id,
            label: option.label,
            iconKey: 'choice',
          ),
        );

    final stateAfter = _ref.read(storyRoomControllerProvider);
    final savedCount = stateAfter.session?.steps.length ?? beforeCount;

    if (savedCount > beforeCount) {
      UxAnalytics.log(
        'story_game_step_saved',
        params: <String, Object?>{
          'source': 'story_game_room_screen',
          'flow': 'game_room',
          'story_id': story.id,
          'step': nextStep,
          'node': nextStep,
          'mode': story.currentMode.name,
          'pending_count': stateAfter.pendingCount,
        },
      );
      return;
    }

    UxAnalytics.log(
      'story_game_step_failed',
      params: <String, Object?>{
        'source': 'story_game_room_screen',
        'flow': 'game_room',
        'story_id': story.id,
        'step': nextStep,
        'node': nextStep,
        'mode': story.currentMode.name,
        'error_kind': stateAfter.error == null ? 'unknown' : 'submit_error',
      },
    );
  }
}

final storyGameControllerProvider =
    StateNotifierProvider.autoDispose<StoryGameController, StoryGameUiState>((
      ref,
    ) {
      return StoryGameController(ref);
    });
