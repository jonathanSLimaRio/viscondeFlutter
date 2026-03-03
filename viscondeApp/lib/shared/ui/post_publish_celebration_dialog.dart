import 'package:flutter/material.dart';

import '../../design_system/visconde.dart';
import '../../features/gamification/inventory_models.dart';
import '../../features/gamification/models/gamification_models.dart';
import '../ux_analytics.dart';

enum PostPublishAction { continueSaga, goGame, backToVault }

Future<PostPublishAction> showPostPublishCelebrationDialog(
  BuildContext context, {
  required String source,
  required String flow,
  required String storyId,
  PublishGamificationSummaryModel? gamification,
  ChildInventoryModel? reward,
}) async {
  final achievements = gamification?.unlockedAchievements ?? const [];
  final shownAchievements = achievements.take(3).toList(growable: false);

  UxAnalytics.log(
    'post_publish_modal_opened',
    params: <String, Object?>{
      'source': source,
      'flow': flow,
      'story_id': storyId,
      'coins_delta': gamification?.deltaCoins ?? 0,
      'stars_delta': gamification?.deltaStars ?? 0,
      'achievements_count': achievements.length,
    },
  );

  void logAction(String target) {
    UxAnalytics.log(
      'post_publish_cta_clicked',
      params: <String, Object?>{
        'source': source,
        'flow': flow,
        'target': target,
      },
    );
  }

  final action = await showDialog<PostPublishAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final textTheme = Theme.of(dialogContext).textTheme;
      final colors = dialogContext.viscondeColors;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Capítulo publicado!'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 0.9 + (value * 0.12),
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      Icons.celebration_rounded,
                      size: 52,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A história foi publicada e a aventura continua. Escolha o próximo passo:',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '+${gamification?.deltaCoins ?? 0} moedas · +${gamification?.deltaStars ?? 0} estrelas',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (achievements.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Conquistas desbloqueadas',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...shownAchievements.map((achievement) {
                    return Text('- ${achievement.title}');
                  }),
                  if (achievements.length > shownAchievements.length)
                    Text(
                      '+${achievements.length - shownAchievements.length} conquista(s)',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                ],
                if (reward?.item != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Item encontrado: ${reward!.item!.name} ${reward.item!.icon}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                logAction('continue_saga');
                Navigator.of(dialogContext).pop(PostPublishAction.continueSaga);
              },
              child: const Text('Continuar saga'),
            ),
            OutlinedButton(
              onPressed: () {
                logAction('go_game');
                Navigator.of(dialogContext).pop(PostPublishAction.goGame);
              },
              child: const Text('Ir para Game'),
            ),
            TextButton(
              onPressed: () {
                logAction('back_to_vault');
                Navigator.of(dialogContext).pop(PostPublishAction.backToVault);
              },
              child: const Text('Voltar ao baú'),
            ),
          ],
        ),
      );
    },
  );

  return action ?? PostPublishAction.backToVault;
}
