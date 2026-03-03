import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../gamification/inventory_models.dart';
import '../../auth/auth_controller.dart';
import '../../story_vault/story_pdf_exporter.dart';
import '../../../shared/logging/app_logger.dart';
import '../../../shared/ui/app_feedback.dart';
import '../../../shared/ui/post_publish_celebration_dialog.dart';
import '../models/story_models.dart';
import '../story_room_controller.dart';
import '../../../shared/ux_analytics.dart';
import '../../../shared/providers.dart';

class StorySummaryScreen extends ConsumerStatefulWidget {
  const StorySummaryScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StorySummaryScreen> createState() => _StorySummaryScreenState();
}

class _StorySummaryScreenState extends ConsumerState<StorySummaryScreen> {
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(storyRoomControllerProvider).session;
      if (session == null || session.id != widget.storyId) {
        ref
            .read(storyRoomControllerProvider.notifier)
            .loadSession(widget.storyId);
      } else {
        _titleController.text = session.title;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _finalize() async {
    final controller = ref.read(storyRoomControllerProvider.notifier);
    final finalized = await controller.finalize(
      titleFinal: _titleController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (finalized == null) {
      final error = ref.read(storyRoomControllerProvider).error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Falha ao publicar.')));
      return;
    }

    UxAnalytics.log(
      'story_published',
      params: <String, Object?>{
        'story_id': finalized.story.id,
        'steps': finalized.story.steps.length,
        'child_id': finalized.story.childProfileId,
        'source': 'story_summary_screen',
      },
    );

    ChildInventoryModel? reward;
    try {
      final token = ref.read(authControllerProvider).accessToken;
      if (token != null) {
        reward = await ref
            .read(inventoryApiProvider)
            .rewardRandomItem(finalized.story.id, token);
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao buscar recompensa pós-publicação na tela de resumo.',
        error: error,
        stackTrace: stackTrace,
        scope: 'story_summary',
      );
    }

    if (!mounted) {
      return;
    }

    final nextAction = await showPostPublishCelebrationDialog(
      context,
      source: 'story_summary_screen',
      flow: 'summary',
      storyId: finalized.story.id,
      gamification: finalized.gamification,
      reward: reward,
    );

    if (!mounted) {
      return;
    }

    await _handlePostPublishAction(nextAction, finalized.story.id);
  }

  Future<void> _handlePostPublishAction(
    PostPublishAction action,
    String storyId,
  ) async {
    switch (action) {
      case PostPublishAction.continueSaga:
        final token = ref.read(authControllerProvider).accessToken;
        if (token == null) {
          if (mounted) {
            context.showMessage('Sua sessão expirou. Faça login novamente.');
            context.go(AppRoute.homePath(tab: HomeTab.stories));
          }
          return;
        }
        try {
          final session = await ref
              .read(storyApiProvider)
              .continueStory(token, storyId);
          if (!mounted) {
            return;
          }
          context.go(AppRoute.storyRoom(session.id));
        } catch (error) {
          if (!mounted) {
            return;
          }
          context.showError(error);
          context.go(AppRoute.homePath(tab: HomeTab.stories));
        }
        return;
      case PostPublishAction.goGame:
        if (mounted) {
          context.go(AppRoute.homePath(tab: HomeTab.game));
        }
        return;
      case PostPublishAction.backToVault:
        if (mounted) {
          context.go(AppRoute.homePath(tab: HomeTab.stories));
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyRoomControllerProvider);
    final story = state.session;

    if (state.loading && story == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (story == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resumo da História')),
        body: const Center(child: Text('História não encontrada.')),
      );
    }

    if (_titleController.text.isEmpty) {
      _titleController.text = story.title;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo e Publicação'),
        actions: [
          IconButton(
            onPressed: () => StoryPdfExporter.exportAndShare(story),
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar história como PDF',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ViscondeHeroBanner(
            title: 'Fechar capítulo',
            subtitle: 'Revise a história antes de publicar.',
            assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroCastle),
            showMascot: true,
            mascotPose: ViscondeMascotPose.enchantedHearts,
          ),
          const SizedBox(height: 12),
          ViscondeGlassCard(
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Título final'),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Criança: ${story.child.name}'),
                        Text('Tema: ${story.theme}'),
                        Text('Cenário: ${story.scenario}'),
                        Text('Objetivo: ${story.objective}'),
                        if (story.virtue != null)
                          Text(
                            'Virtude: ${story.virtue!.name} (faixa ${ageBandLabel(story.ageBand)})',
                          ),
                        if (story.dilemmaText != null &&
                            story.dilemmaText!.trim().isNotEmpty)
                          Text('Dilema: ${story.dilemmaText}'),
                        if (story.endQuestionText != null &&
                            story.endQuestionText!.trim().isNotEmpty)
                          Text('Pergunta do fim: ${story.endQuestionText}'),
                        Text('Etapas salvas: ${story.steps.length}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const ViscondeSectionTitle(
                  title: 'Trechos da aventura',
                  subtitle: 'Momentos registrados na timeline',
                ),
                const SizedBox(height: 8),
                ...story.steps.map(
                  (step) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(step.stepIndex.toString()),
                      ),
                      title: Text(
                        step.selectedOptionLabel ?? step.narratorText ?? '-',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ViscondePrimaryCta(
                  onPressed: state.finalizing ? null : _finalize,
                  icon: Icons.publish,
                  label: state.finalizing
                      ? 'Publicando...'
                      : 'Publicar capítulo',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
