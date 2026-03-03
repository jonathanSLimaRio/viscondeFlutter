import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/story_creation/create_story_wizard_draft_store.dart';
import 'package:visconde_app/features/story_creation/ui/create_story_screen.dart';
import 'package:visconde_app/features/story_room/illustration_api.dart';
import 'package:visconde_app/features/story_room/models/illustration_models.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

class InMemoryCreateStoryDraftStore implements CreateStoryWizardDraftStore {
  final Map<String, CreateStoryWizardDraft> _byUser =
      <String, CreateStoryWizardDraft>{};

  @override
  Future<void> clear(String userId) async {
    _byUser.remove(userId);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<CreateStoryWizardDraft?> read(String userId) async {
    return _byUser[userId];
  }

  @override
  Future<void> save(CreateStoryWizardDraft draft) async {
    _byUser[draft.userId] = draft;
  }
}

class FakeIllustrationApi extends IllustrationApi {
  FakeIllustrationApi(this.styles) : super(Dio());

  final List<ArtStyleModel> styles;

  @override
  Future<List<ArtStyleModel>> listArtStyles() async => styles;
}

StorySessionModel _buildSession() {
  return StorySessionModel(
    id: 'story-resume',
    childProfileId: 'child-1',
    collectionId: 'collection-1',
    episodeNumber: 1,
    sessionKind: StorySessionKind.presencial,
    titleDraft: 'Aventura de Lia',
    title: 'Aventura de Lia',
    theme: 'Aventura',
    scenario: 'Bosque encantado',
    objective: 'Aprender algo novo',
    status: StoryStatus.draft,
    currentMode: StoryMode.parentNarrator,
    currentStepIndex: 1,
    ageSnapshotYears: 8,
    child: StoryChildSnapshot(
      id: 'child-1',
      name: 'Lia',
      birthDate: DateTime(2018, 1, 1),
    ),
    characters: const <StoryCharacterModel>[
      StoryCharacterModel(id: 'c-1', name: 'Lia', role: 'protagonista'),
    ],
    steps: const <StoryStepModel>[],
  );
}

void main() {
  testWidgets('exibe card de rascunho e retoma wizard no passo salvo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final user = buildTestUser();
    final draftStore = InMemoryCreateStoryDraftStore();
    await draftStore.save(
      CreateStoryWizardDraft(
        userId: user.id,
        storyId: 'story-resume',
        currentStep: 2,
        selectedChildId: 'child-1',
        selectedVirtueId: 'virtue-1',
        selectedTemplateId: null,
        selectedArtStyleId: 'style-1',
        mode: StoryMode.parentNarrator,
        titleDraft: 'Aventura de Lia',
        theme: 'Aventura',
        scenario: 'Bosque encantado',
        objective: 'Aprender algo novo',
        characters: 'Lia, Visconde',
        updatedAt: DateTime.now(),
      ),
    );

    final children = <ChildProfile>[
      ChildProfile(
        id: 'child-1',
        name: 'Lia',
        birthDate: DateTime(2018, 1, 1),
        favoriteThemes: const <String>['Aventura'],
        isArchived: false,
      ),
    ];
    final virtues = <VirtueModel>[
      const VirtueModel(
        id: 'virtue-1',
        slug: 'coragem',
        name: 'Coragem',
        shortDescription: 'Seguir em frente',
        iconKey: 'courage',
        sortOrder: 1,
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: user, authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: const <StoryVaultCollectionItem>[],
            virtues: virtues,
            session: _buildSession(),
          ),
        ),
        illustrationApiProvider.overrideWith(
          (ref) => FakeIllustrationApi(
            const <ArtStyleModel>[
              ArtStyleModel(
                id: 'style-1',
                name: 'Aquarela',
                promptTemplate: 'watercolor',
              ),
            ],
          ),
        ),
        createStoryWizardDraftStoreProvider.overrideWithValue(draftStore),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
        child: UncontrolledProviderScope(
          container: container,
          child: const ViscondeApp(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Rascunho em andamento'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateStoryScreen), findsOneWidget);
    expect(find.text('Passo 3 de 3'), findsOneWidget);
  });

  testWidgets('descartar remove card e limpa store local', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final user = buildTestUser();
    final draftStore = InMemoryCreateStoryDraftStore();
    await draftStore.save(
      CreateStoryWizardDraft(
        userId: user.id,
        storyId: 'story-resume',
        currentStep: 1,
        selectedChildId: 'child-1',
        selectedVirtueId: 'virtue-1',
        selectedTemplateId: null,
        selectedArtStyleId: 'style-1',
        mode: StoryMode.parentNarrator,
        titleDraft: 'Aventura de Lia',
        theme: 'Aventura',
        scenario: 'Bosque encantado',
        objective: 'Aprender algo novo',
        characters: 'Lia, Visconde',
        updatedAt: DateTime.now(),
      ),
    );

    final children = <ChildProfile>[
      ChildProfile(
        id: 'child-1',
        name: 'Lia',
        birthDate: DateTime(2018, 1, 1),
        favoriteThemes: const <String>['Aventura'],
        isArchived: false,
      ),
    ];
    final virtues = <VirtueModel>[
      const VirtueModel(
        id: 'virtue-1',
        slug: 'coragem',
        name: 'Coragem',
        shortDescription: 'Seguir em frente',
        iconKey: 'courage',
        sortOrder: 1,
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: user, authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: const <StoryVaultCollectionItem>[],
            virtues: virtues,
            session: _buildSession(),
          ),
        ),
        createStoryWizardDraftStoreProvider.overrideWithValue(draftStore),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
        child: UncontrolledProviderScope(
          container: container,
          child: const ViscondeApp(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Rascunho em andamento'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Rascunho em andamento'), findsNothing);
    final saved = await draftStore.read(user.id);
    expect(saved, isNull);
  });
}
