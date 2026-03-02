import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/story_api.dart';

import '../../helpers/fake_dio_adapter.dart';

Map<String, dynamic> _remoteRoomPayload() {
  return <String, dynamic>{
    'id': 'room-1',
    'status': 'OPEN',
    'callMode': 'AUDIO',
    'maxParticipants': 2,
    'isOpen': true,
    'joinCodeExpiresAt': '2026-03-02T13:00:00.000Z',
    'participants': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'host-1',
        'role': 'HOST_PARENT',
        'displayName': 'Host',
        'status': 'CONNECTED',
        'lastSeenAt': '2026-03-02T12:00:00.000Z',
        'joinedAt': '2026-03-02T11:59:00.000Z',
      },
    ],
  };
}

Map<String, dynamic> _storySnapshotPayload() {
  return <String, dynamic>{
    'id': 'story-1',
    'childProfileId': 'child-1',
    'collectionId': 'collection-1',
    'episodeNumber': 1,
    'sessionKind': 'PRESENTIAL',
    'titleDraft': 'Aventura',
    'title': 'Aventura',
    'theme': 'Amizade',
    'scenario': 'Bosque',
    'objective': 'Ajudar',
    'status': 'DRAFT',
    'currentMode': 'PARENT_NARRATOR',
    'currentStepIndex': 0,
    'ageSnapshotYears': 8,
    'child': <String, dynamic>{
      'id': 'child-1',
      'name': 'Luna',
      'birthDate': '2018-01-01T00:00:00.000Z',
    },
    'characters': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'c-1', 'name': 'Luna'},
    ],
    'steps': <Map<String, dynamic>>[],
  };
}

void main() {
  group('StoryApi remote contracts', () {
    test('openRemoteRoom sends expected endpoint, headers and body', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        captured = options;
        return jsonResponse(<String, dynamic>{
          'joinCode': 'ABC123',
          'joinLink': 'https://visconde.app/remote?code=ABC123',
          'hostParticipantToken': 'host-token',
          'signalingWsUrl': 'wss://realtime.test/ws',
          'rtcConfig': <String, dynamic>{'iceServers': <dynamic>[]},
          'expiresAt': '2026-03-02T13:00:00.000Z',
          'remoteRoom': _remoteRoomPayload(),
        });
      });

      final api = StoryApi(dio);
      final result = await api.openRemoteRoom(
        'access-token',
        'story-1',
        parentalUnlockToken: 'unlock-token',
        callMode: RemoteCallMode.audio,
      );

      expect(captured?.path, '/story-sessions/story-1/remote/open');
      expect(captured?.data, <String, dynamic>{'callMode': 'AUDIO'});
      expect(captured?.headers['Authorization'], 'Bearer access-token');
      expect(captured?.headers['x-parental-unlock-token'], 'unlock-token');
      expect(result.joinCode, 'ABC123');
      expect(result.remoteRoom.id, 'room-1');
    });

    test(
      'joinRemoteRoomByCode sends expected payload and parses snapshot',
      () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        dio.httpClientAdapter = FakeDioAdapter((options) async {
          captured = options;
          return jsonResponse(<String, dynamic>{
            'guestParticipantToken': 'guest-token',
            'remoteRoom': _remoteRoomPayload(),
            'storySnapshot': _storySnapshotPayload(),
            'signalingWsUrl': 'wss://realtime.test/ws',
            'rtcConfig': <String, dynamic>{'iceServers': <dynamic>[]},
          });
        });

        final api = StoryApi(dio);
        final result = await api.joinRemoteRoomByCode(
          code: 'ABC123',
          displayName: 'Luna',
        );

        expect(captured?.path, '/story-sessions/remote/join');
        expect(captured?.data, <String, dynamic>{
          'code': 'ABC123',
          'displayName': 'Luna',
        });
        expect(result.participantToken, 'guest-token');
        expect(result.storySnapshot.id, 'story-1');
        expect(result.remoteRoom.callMode, RemoteCallMode.audio);
      },
    );
  });
}
