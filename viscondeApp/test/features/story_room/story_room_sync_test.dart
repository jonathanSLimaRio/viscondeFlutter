import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/story_api.dart';
import 'package:visconde_app/features/story_room/story_room_controller.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

class FakeConnectivity implements ConnectivityMonitor {
  FakeConnectivity();

  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get changes => _controller.stream;

  void emitOnline() {
    _controller.add(<ConnectivityResult>[ConnectivityResult.wifi]);
  }

  Future<void> disposeFake() async {
    await _controller.close();
  }
}

class QueueTestStoryApi extends StoryApi {
  QueueTestStoryApi(this.session) : super(Dio());

  StorySessionModel session;
  Object? createStepError;
  int createStepCalls = 0;

  @override
  Future<StorySessionModel> createStorySession(
    String accessToken, {
    required String childProfileId,
    required String titleDraft,
    required String theme,
    required String scenario,
    required List<Map<String, String?>> characters,
    required String objective,
    required StoryMode startMode,
    String? virtueId,
    String? sourceTemplateId,
    String? artStyleId,
  }) async {
    return session;
  }

  @override
  Future<StorySessionModel> getStorySession(
    String accessToken,
    String storyId,
  ) async {
    return session;
  }

  @override
  Future<StoryStepSaveResult> createStep(
    String accessToken,
    String storyId, {
    required StoryStepKind kind,
    required int stepIndex,
    String? narratorText,
    String? narratorPrompt,
    String? selectedOptionId,
    String? selectedOptionLabel,
    required String localEventId,
  }) async {
    createStepCalls += 1;
    final error = createStepError;
    if (error != null) {
      throw error;
    }

    return StoryStepSaveResult(story: session, idempotent: false);
  }

  @override
  Future<StorySessionModel> updateMode(
    String accessToken,
    String storyId,
    StoryMode mode,
  ) async {
    session = session.copyWith(currentMode: mode);
    return session;
  }

  @override
  Future<StoryIdeasResult> requestIdeas(
    String accessToken,
    String storyId, {
    String? contextHint,
  }) async {
    return const StoryIdeasResult(
      ideas: <String>['Ideia A', 'Ideia B'],
      source: 'TEST',
      safetyAdjusted: false,
    );
  }

  @override
  Future<StoryFinalizeResult> finalizeStory(
    String accessToken,
    String storyId, {
    String? titleFinal,
  }) async {
    return StoryFinalizeResult(story: session);
  }
}

StorySessionModel _sampleSession() {
  return StorySessionModel(
    id: 'story-1',
    childProfileId: 'child-1',
    collectionId: 'collection-1',
    episodeNumber: 1,
    sessionKind: StorySessionKind.presencial,
    titleDraft: 'Aventura',
    title: 'Aventura',
    theme: 'Amizade',
    scenario: 'Bosque',
    objective: 'Ajudar os amigos',
    status: StoryStatus.draft,
    currentMode: StoryMode.parentNarrator,
    currentStepIndex: 0,
    ageSnapshotYears: 8,
    child: StoryChildSnapshot(
      id: 'child-1',
      name: 'Luna',
      birthDate: DateTime(2018, 1, 1),
    ),
    characters: const <StoryCharacterModel>[
      StoryCharacterModel(id: 'ch-1', name: 'Luna'),
    ],
    steps: const <StoryStepModel>[],
  );
}

Future<void> _waitAuthReady(ProviderContainer container) async {
  for (var i = 0; i < 40; i++) {
    if (container.read(authControllerProvider).status != AuthStatus.loading) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('Auth controller did not leave loading state in time.');
}

void main() {
  group('StoryRoomController sync pending', () {
    test(
      'keeps event as failed on 5xx and does not drop queue entry',
      () async {
        final queue = FakeStorySyncQueue();
        final api = QueueTestStoryApi(_sampleSession());
        final connectivity = FakeConnectivity();

        final container = ProviderContainer(
          overrides: <Override>[
            ...authOverrides(user: buildTestUser()),
            storySyncQueueProvider.overrideWith((ref) => queue),
            storyRoomControllerProvider.overrideWith((ref) {
              return StoryRoomController(
                ref: ref,
                api: api,
                syncQueue: queue,
                connectivity: connectivity,
              );
            }),
          ],
        );

        addTearDown(() async {
          await connectivity.disposeFake();
          container.dispose();
        });

        await _waitAuthReady(container);

        final controller = container.read(storyRoomControllerProvider.notifier);
        await controller.loadSession('story-1');

        api.createStepError = DioException(
          requestOptions: RequestOptions(path: '/story-sessions/story-1/steps'),
          type: DioExceptionType.connectionError,
          error: 'offline',
        );
        await controller.addNarrationStep(narratorText: 'Etapa local');

        expect(await queue.pendingCount(storyId: 'story-1'), 1);

        api.createStepError = DioException(
          requestOptions: RequestOptions(path: '/story-sessions/story-1/steps'),
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: RequestOptions(
              path: '/story-sessions/story-1/steps',
            ),
            statusCode: 500,
            data: <String, dynamic>{'message': 'server down'},
          ),
        );
        await controller.syncPending();

        final counts = await queue.statusCounts(storyId: 'story-1');
        final pending = await queue.listPending(storyId: 'story-1');

        expect(counts.failed, 1);
        expect(counts.unsynced, 1);
        expect(pending, isNotEmpty);
        expect(pending.first.lastError, isNotNull);
      },
    );

    test('retries and marks as synced after connection recovers', () async {
      final queue = FakeStorySyncQueue();
      final api = QueueTestStoryApi(_sampleSession());
      final connectivity = FakeConnectivity();

      final container = ProviderContainer(
        overrides: <Override>[
          ...authOverrides(user: buildTestUser()),
          storySyncQueueProvider.overrideWith((ref) => queue),
          storyRoomControllerProvider.overrideWith((ref) {
            return StoryRoomController(
              ref: ref,
              api: api,
              syncQueue: queue,
              connectivity: connectivity,
            );
          }),
        ],
      );

      addTearDown(() async {
        await connectivity.disposeFake();
        container.dispose();
      });

      await _waitAuthReady(container);

      final controller = container.read(storyRoomControllerProvider.notifier);
      await controller.loadSession('story-1');

      api.createStepError = DioException(
        requestOptions: RequestOptions(path: '/story-sessions/story-1/steps'),
        type: DioExceptionType.connectionError,
        error: 'offline',
      );
      await controller.addNarrationStep(narratorText: 'Etapa local');
      expect(await queue.pendingCount(storyId: 'story-1'), 1);

      api.createStepError = null;
      await controller.syncPending();

      final counts = await queue.statusCounts(storyId: 'story-1');
      final state = container.read(storyRoomControllerProvider);
      expect(counts.unsynced, 0);
      expect(counts.synced, 1);
      expect(state.pendingCount, 0);
      expect(state.syncStatus, StorySyncStatus.synced);
    });

    test('marks queued event as conflict on 409 response', () async {
      final queue = FakeStorySyncQueue();
      final api = QueueTestStoryApi(_sampleSession());
      final connectivity = FakeConnectivity();

      final container = ProviderContainer(
        overrides: <Override>[
          ...authOverrides(user: buildTestUser()),
          storySyncQueueProvider.overrideWith((ref) => queue),
          storyRoomControllerProvider.overrideWith((ref) {
            return StoryRoomController(
              ref: ref,
              api: api,
              syncQueue: queue,
              connectivity: connectivity,
            );
          }),
        ],
      );

      addTearDown(() async {
        await connectivity.disposeFake();
        container.dispose();
      });

      await _waitAuthReady(container);

      final controller = container.read(storyRoomControllerProvider.notifier);
      await controller.loadSession('story-1');

      api.createStepError = DioException(
        requestOptions: RequestOptions(path: '/story-sessions/story-1/steps'),
        type: DioExceptionType.connectionError,
        error: 'offline',
      );
      await controller.addNarrationStep(narratorText: 'Etapa local');

      api.createStepError = DioException(
        requestOptions: RequestOptions(path: '/story-sessions/story-1/steps'),
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/story-sessions/story-1/steps'),
          statusCode: 409,
          data: <String, dynamic>{'message': 'conflict'},
        ),
      );
      await controller.syncPending();

      final counts = await queue.statusCounts(storyId: 'story-1');
      expect(counts.conflict, 1);
      expect(counts.unsynced, 1);
    });

    test(
      'handles createSession, mode change, ideas and finalize flows',
      () async {
        final queue = FakeStorySyncQueue();
        final api = QueueTestStoryApi(_sampleSession());
        final connectivity = FakeConnectivity();

        final container = ProviderContainer(
          overrides: <Override>[
            ...authOverrides(user: buildTestUser()),
            storySyncQueueProvider.overrideWith((ref) => queue),
            storyRoomControllerProvider.overrideWith((ref) {
              return StoryRoomController(
                ref: ref,
                api: api,
                syncQueue: queue,
                connectivity: connectivity,
              );
            }),
          ],
        );

        addTearDown(() async {
          await connectivity.disposeFake();
          container.dispose();
        });

        await _waitAuthReady(container);

        final controller = container.read(storyRoomControllerProvider.notifier);
        final created = await controller.createSession(
          childProfileId: 'child-1',
          titleDraft: 'Aventura',
          theme: 'Amizade',
          scenario: 'Bosque',
          characters: const <Map<String, String?>>[
            <String, String?>{'name': 'Luna', 'role': null},
          ],
          objective: 'Ajudar',
          startMode: StoryMode.parentNarrator,
        );

        expect(created, isNotNull);

        await controller.changeMode(StoryMode.childChooser);
        expect(
          container.read(storyRoomControllerProvider).session?.currentMode,
          StoryMode.childChooser,
        );

        await controller.requestIdeas(contextHint: 'amizade');
        final stateAfterIdeas = container.read(storyRoomControllerProvider);
        expect(stateAfterIdeas.ideas, isNotEmpty);
        expect(stateAfterIdeas.ideasSource, 'TEST');

        final finalized = await controller.finalize(titleFinal: 'Final');
        expect(finalized, isNotNull);
        expect(container.read(storyRoomControllerProvider).finalizing, isFalse);
      },
    );
  });
}
