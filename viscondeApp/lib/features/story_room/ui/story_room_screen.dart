import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../illustration_api.dart';
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

  Future<void> _showNarrateDialog(StoryStepModel step) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final profiles = await ref.read(voiceApiProvider).listProfiles(token);
      if (!mounted) return;

      final readyProfiles = profiles.where((p) => p.status == 'READY').toList();

      if (readyProfiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nenhuma voz pronta encontrada. Acesse a area adulta e treine uma voz primeiro.',
            ),
          ),
        );
        return;
      }

      showModalBottomSheet<void>(
        context: context,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Narrar com a Voz Inesquecivel',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...readyProfiles.map(
                  (p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.relationship ?? ''),
                    trailing: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.green,
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gerando narracao...')),
                        );
                        final job = await ref
                            .read(voiceApiProvider)
                            .requestNarration(
                              token,
                              widget.storyId,
                              step.stepIndex,
                              p.id,
                            );
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Audio gerado!'),
                            content: Text(
                              'O seu audio artificial (MVP) foi criado com sucesso:\n\n${job.outputUrl}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text(
                                  'Fechar',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(parseDioError(e))),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(e))));
    }
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
    final illustrationAsync = ref.watch(
      storyIllustrationProvider((
        storyId: story.id,
        stepIndex: story.currentStepIndex == 0 ? 1 : story.currentStepIndex,
      )),
    );

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
            ViscondeHeroBanner(
              title: story.title,
              subtitle: '${story.theme} · ${story.scenario}',
              assetPath: ViscondeArtRegistry.resolve(
                ViscondeArtKey.heroUnderwater,
              ),
              trailing: ViscondeAvatarBadge(
                imageAsset: ViscondeArtRegistry.resolve(
                  ViscondeArtKey.avatarChild,
                ),
              ),
            ),
            const SizedBox(height: 12),
            illustrationAsync.when(
              data: (illustration) {
                if (illustration == null) return const SizedBox.shrink();

                return Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      if (illustration.imageUrl != null)
                        Image.network(
                          illustration.imageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey[200],
                        ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            illustration.status == 'COMPLETED'
                                ? 'Ilustrando Cena ${illustration.stepIndex}'
                                : 'Criando Ilustracao...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            ViscondeGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            const ViscondeSectionTitle(
              title: 'Timeline da sessão',
              subtitle: 'Cada passo salvo da aventura.',
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
                  trailing: step.kind == StoryStepKind.narration
                      ? IconButton(
                          icon: const Icon(Icons.record_voice_over),
                          tooltip: 'Narrar com Voz da Familia',
                          onPressed: () => _showNarrateDialog(step),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ViscondePrimaryCta(
              onPressed: () => context.push('/stories/${story.id}/summary'),
              icon: Icons.publish_outlined,
              label: 'Revisar e publicar capitulo',
            ),
          ],
        ),
      ),
    );
  }
}
