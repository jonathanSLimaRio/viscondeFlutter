import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/ui/app_feedback.dart';
import '../../../shared/ux_analytics.dart';
import '../../story_room/models/story_models.dart';
import '../../story_room/story_room_controller.dart';
import '../flame/story_trail_game.dart';
import '../story_game_controller.dart';

class StoryGameRoomScreen extends ConsumerStatefulWidget {
  const StoryGameRoomScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryGameRoomScreen> createState() =>
      _StoryGameRoomScreenState();
}

class _StoryGameRoomScreenState extends ConsumerState<StoryGameRoomScreen> {
  final StoryTrailGame _game = StoryTrailGame();
  final TextEditingController _optionalNarrationController =
      TextEditingController();
  int _lastRenderedSteps = 0;
  bool _openedTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(storyRoomControllerProvider.notifier)
          .loadSession(widget.storyId);
    });
  }

  @override
  void dispose() {
    _optionalNarrationController.dispose();
    super.dispose();
  }

  List<StoryGameNodeModel> _fallbackNodes() {
    return List<StoryGameNodeModel>.generate(12, (index) {
      final nodeIndex = index + 1;
      final progress = index / 11;
      final x = 0.08 + progress * 0.84;
      final y = 0.5 + math.sin(progress * math.pi * 2.6) * 0.18;

      return StoryGameNodeModel(
        index: nodeIndex,
        x: x,
        y: y,
        kind: nodeIndex == 1
            ? 'START'
            : nodeIndex == 12
            ? 'FINISH'
            : 'PATH',
      );
    });
  }

  List<StoryTrailNodeSnapshot> _nodeSnapshots({
    required StorySessionModel story,
    required int pendingCount,
  }) {
    final map = story.game?.map;
    final nodes = (map?.nodes.isNotEmpty == true)
        ? map!.nodes
        : _fallbackNodes();

    final ordered = [...nodes]..sort((a, b) => a.index.compareTo(b.index));
    final saved = story.steps.length;
    final completedSynced = math.max(0, saved - pendingCount);

    return ordered.map((node) {
      final index = node.index;
      if (index <= completedSynced) {
        return StoryTrailNodeSnapshot(
          node: node,
          status: StoryTrailNodeStatus.completed,
        );
      }
      if (index <= saved) {
        return StoryTrailNodeSnapshot(
          node: node,
          status: StoryTrailNodeStatus.pending,
        );
      }
      if (index == saved + 1 && story.status == StoryStatus.draft) {
        return StoryTrailNodeSnapshot(
          node: node,
          status: StoryTrailNodeStatus.current,
        );
      }
      return StoryTrailNodeSnapshot(
        node: node,
        status: StoryTrailNodeStatus.locked,
      );
    }).toList();
  }

  int _currentNodeIndex(StorySessionModel story) {
    final totalNodes = story.game?.map.totalNodes ?? 12;
    if (story.status == StoryStatus.published) {
      return math.max(1, math.min(totalNodes, story.steps.length));
    }
    return math.max(1, math.min(totalNodes, story.steps.length + 1));
  }

  Future<void> _submitParentStep(StorySessionModel story) async {
    final controller = ref.read(storyGameControllerProvider.notifier);
    controller.updateOptionalNarrationText(
      _optionalNarrationController.text.trim(),
    );
    await controller.submitParentStep(story);

    if (!mounted) {
      return;
    }

    final state = ref.read(storyRoomControllerProvider);
    if (state.error != null) {
      context.showMessage(state.error!);
      return;
    }

    _optionalNarrationController.clear();
  }

  Future<void> _submitChildStep(
    StorySessionModel story,
    StoryChoiceOption option,
  ) async {
    final controller = ref.read(storyGameControllerProvider.notifier);
    await controller.submitChildChoice(story, option);

    if (!mounted) {
      return;
    }

    final state = ref.read(storyRoomControllerProvider);
    if (state.error != null) {
      context.showMessage(state.error!);
    }
  }

  void _openAdvancedTools(StorySessionModel story) {
    final roomController = ref.read(storyRoomControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sincronizar pendências agora'),
                onTap: () {
                  Navigator.of(context).pop();
                  roomController.syncPending();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(storyRoomControllerProvider);
    final story = roomState.session;
    final gameUiState = ref.watch(storyGameControllerProvider);

    if (roomState.loading && story == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (story == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sala Game')),
        body: const Center(child: Text('Sessão de história não encontrada.')),
      );
    }

    if (!_openedTracked) {
      _openedTracked = true;
      UxAnalytics.log(
        'story_game_room_opened',
        params: <String, Object?>{
          'source': 'story_game_room_screen',
          'flow': 'game_room',
          'story_id': story.id,
          'steps': story.steps.length,
          'mode': story.currentMode.name,
        },
      );
    }

    final snapshots = _nodeSnapshots(
      story: story,
      pendingCount: roomState.pendingCount,
    );
    final currentNode = _currentNodeIndex(story);
    final shouldAnimate = story.steps.length > _lastRenderedSteps;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _game.setSnapshots(
        snapshots,
        currentNodeIndex: currentNode,
        animateAvatar: shouldAnimate,
      );
      _lastRenderedSteps = story.steps.length;
    });

    final roomController = ref.read(storyRoomControllerProvider.notifier);
    final choiceOptions = roomController.currentChoiceOptions();

    return Scaffold(
      appBar: AppBar(
        title: Text(story.title),
        actions: [
          IconButton(
            tooltip: 'Ferramentas avançadas',
            onPressed: () => _openAdvancedTools(story),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ViscondeGlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sala Game da História',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nó ${_currentNodeIndex(story)}/12 · ${roomController.syncLabel()} · ${roomState.pendingCount} pendente(s)',
                        ),
                      ],
                    ),
                  ),
                  ViscondePrimaryCta(
                    onPressed: () =>
                        context.push(AppRoute.storySummary(story.id)),
                    icon: Icons.checklist_outlined,
                    label: 'Revisar capítulo',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: const Color(0xFFF5F7FB),
                  child: GameWidget(game: _game),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ViscondeGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: story.currentMode == StoryMode.parentNarrator
                          ? const Color(0x1A1565C0)
                          : const Color(0x1AE67E22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      story.currentMode == StoryMode.parentNarrator
                          ? 'Agora é o pai'
                          : 'Agora é a criança',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.currentMode == StoryMode.parentNarrator
                        ? 'Ação do narrador'
                        : 'Escolha da criança',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (story.currentMode == StoryMode.parentNarrator) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: StoryGameController.parentActions
                          .map(
                            (action) => ChoiceChip(
                              selected:
                                  action.key ==
                                  gameUiState.selectedParentActionKey,
                              label: Text(action.label),
                              onSelected: roomState.submittingStep
                                  ? null
                                  : (_) {
                                      ref
                                          .read(
                                            storyGameControllerProvider
                                                .notifier,
                                          )
                                          .selectParentAction(action.key);
                                    },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _optionalNarrationController,
                      enabled: !roomState.submittingStep,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Texto opcional para o narrador',
                        hintText: 'Se vazio, usamos a ação escolhida.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: roomState.submittingStep
                          ? null
                          : () => _submitParentStep(story),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        roomState.submittingStep
                            ? 'Salvando passo...'
                            : 'Registrar passo no mapa',
                      ),
                    ),
                  ] else ...[
                    if (choiceOptions.isEmpty)
                      const Text('Ainda não há opções disponíveis.'),
                    ...choiceOptions.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton(
                          onPressed: roomState.submittingStep
                              ? null
                              : () => _submitChildStep(story, option),
                          child: Text(option.label),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
