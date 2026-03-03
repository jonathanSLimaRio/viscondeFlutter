import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/profile/ui/home_shell_screen.dart';
import 'package:visconde_app/features/security/parental_gate_controller.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('Home AppBar shows unlock chip and lock now clears state', (
    tester,
  ) async {
    final user = buildTestUser();
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
        title: 'Aventura',
        theme: 'Aventura',
        virtue: virtues.first,
        isFavorite: false,
        child: const StoryVaultChild(id: 'child-1', name: 'Lia'),
        episodesCount: 1,
        publishedCount: 1,
        draftCount: 0,
        lastReferenceAt: DateTime(2026, 3, 1),
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: user, authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(
            children: [
              ChildProfile(
                id: 'child-1',
                name: 'Lia',
                birthDate: DateTime(2018, 1, 1),
                favoriteThemes: const ['Aventura'],
                isArchived: false,
              ),
            ],
          ),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(collections: collections, virtues: virtues),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(parentalGateControllerProvider.notifier)
        .setUnlocked(
          token: 'unlock-123',
          expiresAt: DateTime.now().add(const Duration(minutes: 8)),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeShellScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Área adulta desbloqueada por'), findsOneWidget);
    expect(find.text('Bloquear agora'), findsOneWidget);

    await tester.tap(find.text('Bloquear agora'));
    await tester.pumpAndSettle();

    expect(container.read(parentalGateControllerProvider).isUnlocked, isFalse);
    expect(find.textContaining('Área adulta desbloqueada por'), findsNothing);
  });
}
