import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/providers.dart';
import '../../../shared/logging/app_logger.dart';
import '../../../shared/ui/app_feedback.dart';
import '../../auth/auth_controller.dart';
import '../../auth/session_persona_controller.dart';
import '../illustration_api.dart';
import '../models/story_models.dart';
import '../story_room_controller.dart';
import 'child_choice_panel.dart';
import 'parent_narrator_panel.dart';
import 'widgets/story_room_header.dart';
import 'widgets/story_room_mission_card.dart';

class StoryRoomScreen extends ConsumerStatefulWidget {
  const StoryRoomScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryRoomScreen> createState() => _StoryRoomScreenState();
}

class _StoryRoomScreenState extends ConsumerState<StoryRoomScreen> {
  int _lastKnownSteps = 0;
  static const int _minimumPublishSteps = 3;

  int _missingStepsForPublish(StorySessionModel story) {
    final missing = _minimumPublishSteps - story.steps.length;
    return missing > 0 ? missing : 0;
  }

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
        return 'Escolha da criança';
      case StoryStepKind.system:
        return 'Sistema';
      case StoryStepKind.narration:
        return 'Narração do pai';
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
    final parentalUnlockToken = await ref
        .read(parentalUnlockServiceProvider)
        .ensureUnlocked(context, source: 'story_room_voice_narration');
    if (parentalUnlockToken == null) {
      return;
    }

    try {
      final profiles = await ref
          .read(voiceApiProvider)
          .listProfiles(parentalUnlockToken: parentalUnlockToken);
      if (!mounted) return;

      final readyProfiles = profiles.where((p) => p.status == 'READY').toList();

      if (readyProfiles.isEmpty) {
        context.showMessage(
          'Nenhuma voz pronta encontrada. Acesse a área adulta e treine uma voz primeiro.',
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
                Text(
                  'Narrar com a Voz Inesquecível',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                        context.showMessage('Gerando narração...');
                        final job = await ref
                            .read(voiceApiProvider)
                            .requestNarration(
                              widget.storyId,
                              step.stepIndex,
                              p.id,
                            );
                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Áudio gerado!'),
                            content: Text(
                              'O seu áudio artificial (MVP) foi criado com sucesso:\n\n${job.outputUrl}',
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
                        if (!context.mounted) return;
                        context.showError(e);
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
      context.showError(e);
    }
  }

  Future<void> _openEditDetailsSheet(StorySessionModel story) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      context.showMessage('Sua sessão expirou. Faça login novamente.');
      return;
    }

    List<VirtueModel> virtues = const <VirtueModel>[];
    try {
      virtues = await ref.read(storyApiProvider).listVirtues(token);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao carregar virtudes para edição de detalhes da história.',
        error: error,
        stackTrace: stackTrace,
        scope: 'story_room',
      );
      virtues = const <VirtueModel>[];
    }

    if (!mounted) {
      return;
    }

    final titleController = TextEditingController(text: story.titleDraft);
    final themeController = TextEditingController(text: story.theme);
    final scenarioController = TextEditingController(text: story.scenario);
    final objectiveController = TextEditingController(text: story.objective);
    final charactersController = TextEditingController(
      text: story.characters.map((character) => character.name).join(', '),
    );

    final roleByName = <String, String?>{
      for (final character in story.characters)
        character.name.trim().toLowerCase(): character.role,
    };

    String? selectedVirtueId = story.virtue?.id;
    if (selectedVirtueId != null &&
        virtues.every((virtue) => virtue.id != selectedVirtueId)) {
      selectedVirtueId = null;
    }
    StoryMode selectedMode = story.currentMode;
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            Future<void> handleSave() async {
              final title = titleController.text.trim();
              final theme = themeController.text.trim();
              final scenario = scenarioController.text.trim();
              final objective = objectiveController.text.trim();

              if (title.isEmpty ||
                  theme.isEmpty ||
                  scenario.isEmpty ||
                  objective.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Preencha título, tema, cenário e objetivo antes de salvar.',
                    ),
                  ),
                );
                return;
              }

              final characterNames = charactersController.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();

              if (characterNames.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Informe ao menos um personagem (separados por vírgula).',
                    ),
                  ),
                );
                return;
              }

              final characters = characterNames
                  .take(8)
                  .map((name) {
                    final role =
                        roleByName[name.toLowerCase()] ??
                        (name.toLowerCase() == 'visconde' ? 'guia' : null);
                    return <String, String?>{
                      'name': name,
                      if (role != null && role.trim().isNotEmpty) 'role': role,
                    };
                  })
                  .toList(growable: false);

              setModalState(() => submitting = true);
              final updated = await ref
                  .read(storyRoomControllerProvider.notifier)
                  .updateSessionSetup(
                    titleDraft: title,
                    theme: theme,
                    scenario: scenario,
                    characters: characters,
                    objective: objective,
                    virtueId: selectedVirtueId,
                    mode: selectedMode,
                    applyAutoVirtue: selectedVirtueId == null,
                  );
              if (!mounted || !sheetContext.mounted) {
                return;
              }
              setModalState(() => submitting = false);

              if (updated == null) {
                final error = ref.read(storyRoomControllerProvider).error;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      error ?? 'Não foi possível atualizar os detalhes.',
                    ),
                  ),
                );
                return;
              }

              Navigator.of(sheetContext).pop();
              context.showMessage('Detalhes da história atualizados.');
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editar detalhes',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                    enabled: !submitting,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: themeController,
                    decoration: const InputDecoration(labelText: 'Tema'),
                    enabled: !submitting,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: scenarioController,
                    decoration: const InputDecoration(labelText: 'Cenário'),
                    enabled: !submitting,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: objectiveController,
                    decoration: const InputDecoration(
                      labelText: 'Objetivo da aventura',
                    ),
                    enabled: !submitting,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: charactersController,
                    decoration: const InputDecoration(
                      labelText: 'Personagens (separados por vírgula)',
                    ),
                    enabled: !submitting,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedVirtueId,
                    decoration: const InputDecoration(
                      labelText: 'Virtude (opcional)',
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Automática (por idade)'),
                      ),
                      ...virtues.map(
                        (virtue) => DropdownMenuItem<String?>(
                          value: virtue.id,
                          child: Text(virtue.name),
                        ),
                      ),
                    ],
                    onChanged: submitting
                        ? null
                        : (value) {
                            setModalState(() => selectedVirtueId = value);
                          },
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<StoryMode>(
                    segments: const [
                      ButtonSegment<StoryMode>(
                        value: StoryMode.parentNarrator,
                        label: Text('Pai narrador'),
                      ),
                      ButtonSegment<StoryMode>(
                        value: StoryMode.childChooser,
                        label: Text('Criança escolhe'),
                      ),
                    ],
                    selected: <StoryMode>{selectedMode},
                    onSelectionChanged: submitting
                        ? null
                        : (values) {
                            setModalState(() => selectedMode = values.first);
                          },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: submitting ? null : handleSave,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(submitting ? 'Salvando...' : 'Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    themeController.dispose();
    scenarioController.dispose();
    objectiveController.dispose();
    charactersController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StoryRoomState>(storyRoomControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }

      final previousSteps = previous?.session?.steps.length ?? _lastKnownSteps;
      final currentSteps = next.session?.steps.length ?? previousSteps;
      if (currentSteps > previousSteps) {
        context.showMessage(
          'Etapa salva. Próximo passo: continue narrando ou revise para publicar.',
        );
      }
      _lastKnownSteps = currentSteps;
    });

    final state = ref.watch(storyRoomControllerProvider);
    final controller = ref.read(storyRoomControllerProvider.notifier);
    final personaState = ref.watch(sessionPersonaControllerProvider);
    final isTogetherMode = personaState.isTogetherMode;
    final story = state.session;

    if (state.loading && story == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (story == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sala de História')),
        body: const Center(child: Text('Sessão de história não encontrada.')),
      );
    }

    final options = controller.currentChoiceOptions();
    final missingStepsForPublish = _missingStepsForPublish(story);
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
            onPressed: () => context.push(AppRoute.storySummary(story.id)),
            icon: const Icon(Icons.checklist_outlined),
            tooltip: 'Resumo e publicação',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadSession(story.id),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StoryRoomHeader(
              title: story.title,
              currentStep: story.currentStepIndex == 0
                  ? 1
                  : story.currentStepIndex,
              totalSteps: 12,
              themeArtKey: ViscondeArtKey
                  .heroUnderwater, // We should dynamically choose based on theme, hardcoded to underwater to match UI
              xp: 340, // Mocked for UI
              maxXp: 500, // Mocked for UI
            ),
            if (story.status == StoryStatus.draft) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: state.loading
                      ? null
                      : () => _openEditDetailsSheet(story),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Editar detalhes'),
                ),
              ),
            ],
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
                                : 'Criando Ilustração...',
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
            StoryRoomMissionCard(missionText: story.objective),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          controller.changeMode(StoryMode.parentNarrator),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: story.currentMode == StoryMode.parentNarrator
                              ? const Color(0xFF426B1F) // Green selected
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person,
                              color:
                                  story.currentMode == StoryMode.parentNarrator
                                  ? Colors.white
                                  : Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pai narrador',
                              style: TextStyle(
                                color:
                                    story.currentMode ==
                                        StoryMode.parentNarrator
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          controller.changeMode(StoryMode.childChooser),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: story.currentMode == StoryMode.childChooser
                              ? const Color(
                                  0xFFEFE8D8,
                                ) // Light variant selected
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.radio_button_unchecked,
                              color: story.currentMode == StoryMode.childChooser
                                  ? Colors.black87
                                  : Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Criança escolhe',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      story.currentMode ==
                                          StoryMode.childChooser
                                      ? Colors.black87
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
            ViscondeGlassCard(
              child: ExpansionTile(
                title: const Text('Ferramentas avançadas'),
                subtitle: Text(
                  'Sincronização: ${controller.syncLabel()} · Pendentes: ${state.pendingCount}',
                ),
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Sincronizar pendências agora'),
                    onTap: state.syncStatus == StorySyncStatus.reconnecting
                        ? null
                        : controller.syncPending,
                  ),
                  isTogetherMode
                      ? const ListTile(
                          enabled: false,
                          leading: Icon(Icons.link_off_rounded),
                          title: Text('Sala remota indisponível'),
                          subtitle: Text(
                            'Modo Pai e Filho no mesmo celular desativa o WebRTC.',
                          ),
                        )
                      : ListTile(
                          leading: const Icon(Icons.video_call_outlined),
                          title: const Text('Abrir sala remota'),
                          onTap: () =>
                              context.push(AppRoute.storyRemote(story.id)),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const ViscondeSectionTitle(
              title: 'Sua jornada até aqui',
              subtitle: 'Cada passo salvo da aventura.',
            ),
            const SizedBox(height: 8),
            if (story.steps.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Ainda sem etapas salvas.'),
              ),
            ...story.steps.map(
              (step) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8C4),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4B483),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stepTitle(step),
                            style: const TextStyle(
                              color: Color(0xFF3E281B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _stepText(step),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B5446),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (step.kind == StoryStepKind.narration)
                      IconButton(
                        icon: const Icon(
                          Icons.record_voice_over,
                          color: Color(0xFF3E281B),
                        ),
                        tooltip: 'Narrar com Voz da Família',
                        onPressed: () => _showNarrateDialog(step),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (missingStepsForPublish > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Ao publicar no resumo, completaremos automaticamente '
                  '$missingStepsForPublish ${missingStepsForPublish == 1 ? 'etapa' : 'etapas'} restantes.',
                ),
              ),
            ViscondePrimaryCta(
              onPressed: () => context.push(AppRoute.storySummary(story.id)),
              icon: Icons.publish_outlined,
              label: missingStepsForPublish == 0
                  ? 'Revisar e publicar capítulo'
                  : 'Revisar e publicar com auto-complete',
            ),
          ],
        ),
      ),
    );
  }
}
