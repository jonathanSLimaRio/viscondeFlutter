import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/design_system/visconde.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('ViscondeGlassCard golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 280));
    await tester.pumpWidget(
      wrapTestApp(
        Center(
          child: SizedBox(
            width: 280,
            child: ViscondeGlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Baú'),
                  SizedBox(height: 8),
                  Text('4 histórias'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/design_system/visconde_glass_card.png'),
    );
  });

  testWidgets('ViscondePrimaryCta golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 220));
    await tester.pumpWidget(
      wrapTestApp(
        Center(
          child: SizedBox(
            width: 280,
            child: ViscondePrimaryCta(
              onPressed: () {},
              icon: Icons.play_arrow,
              label: 'Começar História',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/design_system/visconde_primary_cta.png'),
    );
  });

  testWidgets('ViscondeStoryRowCard golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 240));
    await tester.pumpWidget(
      wrapTestApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: ViscondeStoryRowCard(
            title: 'Mistério na Floresta',
            badgeLabel: 'Coragem',
            backgroundAsset: ViscondeArtRegistry.resolve(
              ViscondeArtKey.heroForest,
            ),
            trailing: const Icon(Icons.star, color: Colors.amber),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/design_system/visconde_story_row_card.png'),
    );
  });

  testWidgets('ViscondeHeroBanner golden without mascot', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 300));
    await tester.pumpWidget(
      wrapTestApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: ViscondeHeroBanner(
            title: 'Baú de Aventuras',
            subtitle: '4 histórias salvas',
            assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroTreasure),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/design_system/visconde_hero_banner_without_mascot.png',
      ),
    );
  });

  testWidgets('ViscondeHeroBanner golden with mascot', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 300));
    await tester.pumpWidget(
      wrapTestApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: ViscondeHeroBanner(
            title: 'Baú de Aventuras',
            subtitle: '4 histórias salvas',
            assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroTreasure),
            showMascot: true,
            mascotPose: ViscondeMascotPose.readingBook,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/design_system/visconde_hero_banner_with_mascot.png',
      ),
    );
  });

  testWidgets('ViscondeHeroBanner golden compact modern', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 280));
    await tester.pumpWidget(
      wrapTestApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: ViscondeHeroBanner(
            title: 'Baú de Aventuras',
            subtitle: '4 histórias salvas · continuar em 1 toque',
            variant: ViscondeHeroBannerVariant.compactModern,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/design_system/visconde_hero_banner_compact_modern.png',
      ),
    );
  });
}
