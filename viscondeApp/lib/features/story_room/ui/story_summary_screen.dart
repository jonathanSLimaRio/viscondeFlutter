import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../gamification/models/gamification_models.dart';
import '../../gamification/inventory_models.dart';
import '../../auth/auth_controller.dart';
import '../../story_vault/story_pdf_exporter.dart';
import '../models/story_models.dart';
import '../story_room_controller.dart';
import '../../../shared/ux_analytics.dart';
import '../../../shared/providers.dart';

enum _PostPublishAction { home, nextAdventure }

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
      },
    );

    ChildInventoryModel? reward;
    try {
      final token = ref.read(authControllerProvider).accessToken;
      if (token != null) {
        reward = await ref
            .read(inventoryApiProvider)
            .rewardRandomItem(widget.storyId, token);
      }
    } catch (_) {}

    final nextAction = await _showGamificationModal(
      finalized.gamification,
      reward: reward,
    );

    if (!mounted) {
      return;
    }

    if (nextAction == _PostPublishAction.nextAdventure) {
      context.go(AppRoute.storyCreate);
      return;
    }
    context.go(AppRoute.home);
  }

  Future<_PostPublishAction> _showGamificationModal(
    PublishGamificationSummaryModel? gamification, {
    ChildInventoryModel? reward,
  }) async {
    if (!mounted) {
      return _PostPublishAction.home;
    }

    UxAnalytics.log(
      'reward_modal_opened',
      params: <String, Object?>{
        'has_gamification': gamification != null,
        'has_reward_item': reward?.item != null,
      },
    );

    final action = await showDialog<_PostPublishAction>(
      context: context,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        final colors = context.viscondeColors;
        return AlertDialog(
          title: const Text('Capítulo publicado!'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.86, end: 1),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: Icon(
                      Icons.celebration_rounded,
                      size: 44,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Parabéns! A história já está no baú e a aventura segue viva.',
                  style: textTheme.bodyMedium,
                ),
                if (gamification != null) ...[
                  const SizedBox(height: 12),
                  Text('+${gamification.deltaCoins} moedas'),
                  Text('+${gamification.deltaStars} estrelas'),
                  const SizedBox(height: 8),
                  Text(
                    'Carteira: ${gamification.wallet.coins} moedas · ${gamification.wallet.stars} estrelas',
                  ),
                  const SizedBox(height: 8),
                  Text('Streak atual: ${gamification.streak.currentDays} dias'),
                  Text('Escudos: ${gamification.streak.shieldCount}'),
                ],
                if (reward != null && reward.item != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Item Encontrado',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  Text('Você achou: ${reward.item!.name} ${reward.item!.icon}'),
                  Text(
                    '${reward.item!.rarity} - ${reward.item!.description}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
                if (gamification?.completedMissions.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Missões concluídas',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...gamification!.completedMissions.map<Widget>(
                    (mission) => Text('- ${mission.title}'),
                  ),
                ],
                if (gamification?.unlockedAchievements.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Conquistas desbloqueadas',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...gamification!.unlockedAchievements.map<Widget>(
                    (achievement) => Text('- ${achievement.title}'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                UxAnalytics.log(
                  'reward_modal_cta_clicked',
                  params: const <String, Object?>{'target': 'home'},
                );
                Navigator.of(context).pop(_PostPublishAction.home);
              },
              child: const Text('Voltar ao início'),
            ),
            FilledButton(
              onPressed: () {
                UxAnalytics.log(
                  'reward_modal_cta_clicked',
                  params: const <String, Object?>{'target': 'next_adventure'},
                );
                Navigator.of(context).pop(_PostPublishAction.nextAdventure);
              },
              child: const Text('Próxima aventura'),
            ),
          ],
        );
      },
    );

    return action ?? _PostPublishAction.home;
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
