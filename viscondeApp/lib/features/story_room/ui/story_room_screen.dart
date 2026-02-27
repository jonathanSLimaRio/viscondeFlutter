import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/story_models.dart';
import '../story_room_controller.dart';
import 'child_choice_panel.dart';
import 'parent_narrator_panel.dart';

class StoryRoomScreen extends ConsumerStatefulWidget {
  const StoryRoomScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryRoomScreen> createState() => _StoryRoomScreenState();
}

class _StoryRoomScreenState extends ConsumerState<StoryRoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(storyRoomControllerProvider.notifier)
          .loadSession(widget.storyId);
    });
  }

  String _stepTitle(StoryStepModel step) {
    switch (step.kind) {
      case StoryStepKind.childChoice:
        return 'Escolha da crianca';
      case StoryStepKind.system:
        return 'Sistema';
      case StoryStepKind.narration:
        return 'Narracao do pai';
    }
  }

  String _stepText(StoryStepModel step) {
    return step.selectedOptionLabel ??
        step.narratorText ??
        step.narratorPrompt ??
        '-';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StoryRoomState>(storyRoomControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final state = ref.watch(storyRoomControllerProvider);
    final controller = ref.read(storyRoomControllerProvider.notifier);
    final story = state.session;

    if (state.loading && story == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (story == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sala de Historia')),
        body: const Center(child: Text('Sessao de historia nao encontrada.')),
      );
    }

    final options = controller.currentChoiceOptions();

    return Scaffold(
      appBar: AppBar(
        title: Text(story.title),
        actions: [
          IconButton(
            onPressed: state.syncStatus == StorySyncStatus.reconnecting
                ? null
                : controller.syncPending,
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar pendentes',
          ),
          IconButton(
            onPressed: () => context.push('/stories/${story.id}/remote'),
            icon: const Icon(Icons.video_call_outlined),
            tooltip: 'Sala remota',
          ),
          IconButton(
            onPressed: () => context.push('/stories/${story.id}/summary'),
            icon: const Icon(Icons.checklist_outlined),
            tooltip: 'Resumo e publicacao',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadSession(story.id),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${story.theme} · ${story.scenario}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Objetivo: ${story.objective}'),
                    if (story.virtue != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Virtude: ${story.virtue!.name} (faixa ${ageBandLabel(story.ageBand)})',
                      ),
                    ],
                    if (story.dilemmaText != null &&
                        story.dilemmaText!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Dilema: ${story.dilemmaText!}'),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Etapa ${story.currentStepIndex}/12')),
                        Chip(label: Text(controller.syncLabel())),
                        Chip(label: Text('${state.pendingCount} pendentes')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<StoryMode>(
              segments: const [
                ButtonSegment<StoryMode>(
                  value: StoryMode.parentNarrator,
                  label: Text('Pai narrador'),
                ),
                ButtonSegment<StoryMode>(
                  value: StoryMode.childChooser,
                  label: Text('Crianca escolhe'),
                ),
              ],
              selected: <StoryMode>{story.currentMode},
              onSelectionChanged: (values) {
                controller.changeMode(values.first);
              },
            ),
            const SizedBox(height: 16),
            if (story.currentMode == StoryMode.parentNarrator)
              ParentNarratorPanel(
                loading: state.submittingStep || state.loading,
                ideas: state.ideas,
                ideasSource: state.ideasSource,
                ideasSafetyAdjusted: state.ideasSafetyAdjusted,
                onSaveNarration: (text) {
                  controller.addNarrationStep(narratorText: text);
                },
                onRequestIdeas: (hint) {
                  controller.requestIdeas(contextHint: hint);
                },
              )
            else
              ChildChoicePanel(
                enabled: !(state.submittingStep || state.loading),
                options: options,
                onSelect: (option) {
                  controller.addChildChoiceStep(
                    selectedOptionLabel: option.label,
                    selectedOptionId: option.id,
                  );
                },
              ),
            const SizedBox(height: 20),
            const Text(
              'Timeline da sessao',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (story.steps.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Ainda sem etapas salvas.'),
              ),
            ...story.steps.map(
              (step) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(step.stepIndex.toString())),
                  title: Text(_stepTitle(step)),
                  subtitle: Text(_stepText(step)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => context.push('/stories/${story.id}/summary'),
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Revisar e publicar capitulo'),
            ),
          ],
        ),
      ),
    );
  }
}
