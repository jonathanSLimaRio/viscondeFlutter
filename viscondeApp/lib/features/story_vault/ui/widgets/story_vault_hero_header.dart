import 'package:flutter/material.dart';

import '../../../../design_system/visconde.dart';
import 'story_vault_ui_models.dart';

class StoryVaultHeroHeader extends StatelessWidget {
  const StoryVaultHeroHeader({
    super.key,
    required this.title,
    required this.stats,
    required this.heroAssetPath,
    required this.onViewCollection,
  });

  final String title;
  final List<VaultHeaderStatsModel> stats;
  final String heroAssetPath;
  final VoidCallback onViewCollection;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    final radii = context.viscondeRadii;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radii.xl + 6),
        border: Border.all(color: colors.borderSoft, width: 1.4),
        boxShadow: context.viscondeElevations.card,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.52),
            Colors.white.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: ViscondeGlassCard(
        radius: radii.xl,
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -22,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.accent.withValues(alpha: 0.36),
                      colors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: stats
                            .map(
                              (item) => _StatPill(
                                label: item.label,
                                value: item.value,
                                icon: item.icon,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Image.asset(heroAssetPath, fit: BoxFit.contain),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: OutlinedButton(
                onPressed: onViewCollection,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                  side: BorderSide(color: colors.primaryDark.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: const Text('Ver coleção'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, this.icon});

  final String label;
  final int value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: context.viscondeGradients.pill,
        borderRadius: BorderRadius.circular(context.viscondeRadii.sm),
        border: Border.all(color: colors.borderSoft, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colors.primaryDark),
            const SizedBox(width: 6),
          ],
          Text(
            '$label: $value',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
