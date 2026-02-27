import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/auth/ui/login_screen.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_vault/ui/story_vault_screen.dart';
import 'package:visconde_app/shared/providers.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('LoginScreen golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await tester.pumpWidget(
      wrapTestApp(
        const LoginScreen(),
        overrides: authOverrides(user: buildTestUser(), authenticated: false),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/features/auth/login_screen.png'),
    );
  });

  testWidgets('StoryVaultScreen golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final virtues = [
      const VirtueModel(
        id: 'v1',
        slug: 'coragem',
        name: 'Coragem',
        shortDescription: 'Seguir em frente',
        iconKey: 'courage',
        sortOrder: 1,
      ),
    ];

    final collections = [
      StoryVaultCollectionItem(
        id: 'col-1',
        title: 'Mistério na Floresta',
        theme: 'Aventura',
        virtue: virtues.first,
        isFavorite: true,
        child: const StoryVaultChild(id: 'child-1', name: 'Lucas'),
        episodesCount: 4,
        publishedCount: 3,
        draftCount: 1,
        lastReferenceAt: DateTime(2026, 2, 26, 18, 30),
        latestEpisode: StoryVaultLatestEpisode(
          storyId: 's1',
          episodeNumber: 4,
          title: 'Capítulo 4',
          status: StoryStatus.draft,
          updatedAt: DateTime(2026, 2, 26, 18, 30),
          currentStepIndex: 5,
        ),
      ),
    ];

    final children = [
      ChildProfile(
        id: 'child-1',
        name: 'Lucas',
        birthDate: DateTime(2018, 1, 1),
        favoriteThemes: const ['Aventura'],
        isArchived: false,
      ),
    ];

    await tester.pumpWidget(
      wrapTestApp(
        const StoryVaultScreen(),
        overrides: [
          ...authOverrides(user: buildTestUser(), authenticated: true),
          childrenApiProvider.overrideWith(
            (ref) => FakeChildrenApi(children: children),
          ),
          storyApiProvider.overrideWith(
            (ref) => FakeStoryApi(collections: collections, virtues: virtues),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StoryVaultScreen),
      matchesGoldenFile('goldens/features/story_vault/story_vault_screen.png'),
    );
  });
}
