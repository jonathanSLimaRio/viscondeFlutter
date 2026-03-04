import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/story_api.dart';

import '../../helpers/fake_dio_adapter.dart';

Map<String, dynamic> _sessionPayload() {
  return <String, dynamic>{
    'id': 'story-1',
    'childProfileId': 'child-1',
    'collectionId': 'collection-1',
    'episodeNumber': 1,
    'sessionKind': 'PRESENTIAL',
    'titleDraft': 'Aventura de Sofia',
    'title': 'Aventura de Sofia',
    'theme': 'Aventura',
    'scenario': 'Bosque',
    'objective': 'Aprender coragem',
    'status': 'DRAFT',
    'currentMode': 'PARENT_NARRATOR',
    'currentStepIndex': 0,
    'ageSnapshotYears': 8,
    'child': <String, dynamic>{
      'id': 'child-1',
      'name': 'Sofia',
      'birthDate': '2018-01-01T00:00:00.000Z',
    },
    'characters': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'c-1', 'name': 'Sofia'},
    ],
    'steps': <Map<String, dynamic>>[],
  };
}

void main() {
  group('StoryApi character payload sanitization', () {
    test('createStorySession removes nullable and empty role values', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        captured = options;
        return jsonResponse(_sessionPayload());
      });
      final api = StoryApi(dio);

      await api.createStorySession(
        'access-token',
        childProfileId: 'child-1',
        titleDraft: 'Aventura de Sofia',
        theme: 'Aventura',
        scenario: 'Bosque',
        characters: <Map<String, String?>>[
          <String, String?>{'name': ' Sofia ', 'role': null},
          <String, String?>{'name': 'Visconde', 'role': ' guia '},
          <String, String?>{'name': 'Lia', 'role': '   '},
          <String, String?>{'name': '   ', 'role': 'amiga'},
        ],
        objective: 'Aprender coragem',
        startMode: StoryMode.parentNarrator,
      );

      final data = captured?.data as Map<String, dynamic>?;
      expect(data, isNotNull);
      expect(data?['characters'], <Map<String, String>>[
        <String, String>{'name': 'Sofia'},
        <String, String>{'name': 'Visconde', 'role': 'guia'},
        <String, String>{'name': 'Lia'},
      ]);
    });

    test(
      'updateStorySessionSetup sends sanitized characters payload',
      () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        dio.httpClientAdapter = FakeDioAdapter((options) async {
          captured = options;
          return jsonResponse(_sessionPayload());
        });
        final api = StoryApi(dio);

        await api.updateStorySessionSetup(
          'access-token',
          'story-1',
          titleDraft: 'Aventura de Sofia',
          theme: 'Aventura',
          scenario: 'Bosque',
          objective: 'Aprender coragem',
          characters: <Map<String, String?>>[
            <String, String?>{'name': ' Sofia ', 'role': null},
            <String, String?>{'name': 'Visconde', 'role': 'guia'},
            <String, String?>{'name': 'Lia', 'role': ''},
          ],
        );

        final data = captured?.data as Map<String, dynamic>?;
        expect(data, isNotNull);
        expect(data?['characters'], <Map<String, String>>[
          <String, String>{'name': 'Sofia'},
          <String, String>{'name': 'Visconde', 'role': 'guia'},
          <String, String>{'name': 'Lia'},
        ]);
      },
    );
  });
}
