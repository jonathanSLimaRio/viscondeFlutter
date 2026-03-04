import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/auth/session_persona_controller.dart';
import 'package:visconde_app/features/story_room/illustration_api.dart';
import 'package:visconde_app/features/story_room/models/illustration_models.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/story_api.dart';
import 'package:visconde_app/features/story_room/story_room_controller.dart';
import 'package:visconde_app/features/story_room/ui/story_room_screen.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

class _StaticAuthController extends AuthController {
  _StaticAuthController()
    : super(
        api: FakeAuthApi(user: buildTestUser()),
        sessionStorage: MemorySessionStorage(
          buildStoredSession(buildTestUser()),
        ),
      ) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: buildTestUser(),
      accessToken: 'token-123',
      refreshToken: 'refresh-123',
    );
  }
}

class _FakeConnectivityMonitor implements ConnectivityMonitor {
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get changes => _controller.stream;

  Future<void> disposeFake() async {
    await _controller.close();
  }
}

class _StoryRoomUiApi extends StoryApi {
  _StoryRoomUiApi(this.session) : super(Dio());

  final StorySessionModel session;

  @override
  Future<StorySessionModel> getStorySession(
    String accessToken,
    String storyId,
  ) async {
    return session;
  }
}

class _FakeIllustrationApi extends IllustrationApi {
  _FakeIllustrationApi() : super(Dio());

  @override
  Future<StoryIllustrationModel?> getStoryIllustration(
    String storyId,
    int stepIndex,
  ) async {
    return StoryIllustrationModel(
      id: 'illustration-1',
      storyId: storyId,
      stepIndex: stepIndex,
      status: 'PENDING',
      imageUrl: null,
    );
  }
}

StorySessionModel _sampleSession() {
  return StorySessionModel(
    id: 'story-1',
    childProfileId: 'child-1',
    collectionId: 'col-1',
    episodeNumber: 1,
    sessionKind: StorySessionKind.presencial,
    titleDraft: 'Aventura de Teste',
    title: 'Aventura de Teste',
    theme: 'Aventura',
    scenario: 'Floresta',
    objective: 'Ajudar um amigo',
    status: StoryStatus.draft,
    currentMode: StoryMode.parentNarrator,
    currentStepIndex: 1,
    ageSnapshotYears: 8,
    child: StoryChildSnapshot(
      id: 'child-1',
      name: 'Luna',
      birthDate: DateTime(2018, 1, 1),
    ),
    characters: const [StoryCharacterModel(id: 'ch-1', name: 'Luna')],
    steps: const [],
  );
}

void main() {
  testWidgets('modo juntos desabilita acesso de sala remota no StoryRoom', (
    tester,
  ) async {
    final connectivity = _FakeConnectivityMonitor();
    final queue = FakeStorySyncQueue();
    final storyApi = _StoryRoomUiApi(_sampleSession());

    addTearDown(() async {
      await connectivity.disposeFake();
      await queue.dispose();
    });

    await tester.pumpWidget(
      wrapTestApp(
        const StoryRoomScreen(storyId: 'story-1'),
        overrides: [
          authControllerProvider.overrideWith((ref) => _StaticAuthController()),
          sessionPersonaControllerProvider.overrideWith((ref) {
            final controller = SessionPersonaController();
            controller.selectParentTogether();
            return controller;
          }),
          illustrationApiProvider.overrideWith((ref) => _FakeIllustrationApi()),
          storyRoomControllerProvider.overrideWith((ref) {
            return StoryRoomController(
              ref: ref,
              api: storyApi,
              syncQueue: queue,
              connectivity: connectivity,
            );
          }),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Aventura de Teste'), findsWidgets);
    final advancedToolsFinder = find.text('Ferramentas avançadas');
    await tester.scrollUntilVisible(
      advancedToolsFinder,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(advancedToolsFinder);
    await tester.pumpAndSettle();

    expect(find.text('Sala remota indisponível'), findsOneWidget);
    expect(find.textContaining('desativa o WebRTC'), findsOneWidget);
    expect(find.text('Abrir sala remota'), findsNothing);
  });

  testWidgets('modo separado mantém acesso de sala remota no StoryRoom', (
    tester,
  ) async {
    final connectivity = _FakeConnectivityMonitor();
    final queue = FakeStorySyncQueue();
    final storyApi = _StoryRoomUiApi(_sampleSession());

    addTearDown(() async {
      await connectivity.disposeFake();
      await queue.dispose();
    });

    await tester.pumpWidget(
      wrapTestApp(
        const StoryRoomScreen(storyId: 'story-1'),
        overrides: [
          authControllerProvider.overrideWith((ref) => _StaticAuthController()),
          sessionPersonaControllerProvider.overrideWith((ref) {
            final controller = SessionPersonaController();
            controller.selectParent();
            return controller;
          }),
          illustrationApiProvider.overrideWith((ref) => _FakeIllustrationApi()),
          storyRoomControllerProvider.overrideWith((ref) {
            return StoryRoomController(
              ref: ref,
              api: storyApi,
              syncQueue: queue,
              connectivity: connectivity,
            );
          }),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Aventura de Teste'), findsWidgets);
    final advancedToolsFinder = find.text('Ferramentas avançadas');
    await tester.scrollUntilVisible(
      advancedToolsFinder,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(advancedToolsFinder);
    await tester.pumpAndSettle();

    expect(find.text('Abrir sala remota'), findsOneWidget);
    expect(find.text('Sala remota indisponível'), findsNothing);
  });
}
