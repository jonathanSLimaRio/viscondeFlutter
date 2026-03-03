import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/core/network/api_exception.dart';
import 'package:visconde_app/features/security/voice_api.dart';

import '../../helpers/fake_dio_adapter.dart';

void main() {
  group('VoiceApi', () {
    test('listProfiles returns profiles on success payload', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        captured = options;
        return jsonResponse([
          {
            'id': 'vp-1',
            'name': 'Papai',
            'relationship': 'PAI',
            'status': 'READY',
            'createdAt': '2026-03-01T10:00:00.000Z',
          },
        ]);
      });

      final api = VoiceApi(dio);
      final result = await api.listProfiles(
        parentalUnlockToken: 'unlock-token',
      );

      expect(captured?.path, 'voices');
      expect(captured?.headers['x-parental-unlock-token'], 'unlock-token');
      expect(result, hasLength(1));
      expect(result.first.id, 'vp-1');
      expect(result.first.status, 'READY');
    });

    test('requestNarration uses contract path without v1 prefix', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        captured = options;
        return jsonResponse({
          'id': 'job-1',
          'storyId': 'story-1',
          'stepIndex': 2,
          'status': 'COMPLETED',
          'outputUrl': 'https://cdn.test/audio.mp3',
        });
      });

      final api = VoiceApi(dio);
      final result = await api.requestNarration('story-1', 2, 'vp-1');

      expect(captured?.path, 'stories/story-1/narrate');
      expect(captured?.data, {'stepIndex': 2, 'voiceProfileId': 'vp-1'});
      expect(result.id, 'job-1');
      expect(result.outputUrl, isNotNull);
    });

    test('createProfile posts expected payload', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        captured = options;
        return jsonResponse({
          'id': 'vp-2',
          'name': 'Mamãe',
          'relationship': 'MAE',
          'status': 'PENDING',
          'createdAt': '2026-03-01T10:00:00.000Z',
        });
      });

      final api = VoiceApi(dio);
      final result = await api.createProfile(
        name: 'Mamãe',
        relationship: 'MAE',
        parentalUnlockToken: 'unlock-token',
      );

      expect(captured?.path, 'voices');
      expect(captured?.data, {'name': 'Mamãe', 'relationship': 'MAE'});
      expect(captured?.headers['x-parental-unlock-token'], 'unlock-token');
      expect(result.id, 'vp-2');
    });

    test('trainProfile posts training command endpoint', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        captured = options;
        return jsonResponse(<String, dynamic>{});
      });

      final api = VoiceApi(dio);
      await api.trainProfile('vp-2', parentalUnlockToken: 'unlock-token');

      expect(captured?.path, 'voices/vp-2/train');
      expect(captured?.method, 'POST');
      expect(captured?.headers['x-parental-unlock-token'], 'unlock-token');
    });

    test(
      'listProfiles maps parental unlock 401 into parentalUnlock ApiException',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        dio.httpClientAdapter = FakeDioAdapter((options) async {
          return jsonResponse({
            'error': 'Área protegida por PIN.',
            'code': 'PARENTAL_UNLOCK_REQUIRED',
          }, statusCode: 401);
        });

        final api = VoiceApi(dio);

        await expectLater(
          api.listProfiles(parentalUnlockToken: 'unlock-token'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.kind, 'kind', ApiErrorKind.parentalUnlock)
                .having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      },
    );

    test('listProfiles maps 500 into server ApiException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        return jsonResponse({'message': 'Internal error'}, statusCode: 500);
      });

      final api = VoiceApi(dio);

      await expectLater(
        api.listProfiles(parentalUnlockToken: 'unlock-token'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.server)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('listProfiles maps timeout into timeout ApiException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      });

      final api = VoiceApi(dio);

      await expectLater(
        api.listProfiles(parentalUnlockToken: 'unlock-token'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.timeout,
          ),
        ),
      );
    });

    test(
      'listProfiles wraps unexpected payload parsing as unknown ApiException',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        dio.httpClientAdapter = FakeDioAdapter((_) async {
          return jsonResponse([1, 2, 3]);
        });

        final api = VoiceApi(dio);

        await expectLater(
          api.listProfiles(parentalUnlockToken: 'unlock-token'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiErrorKind.unknown,
            ),
          ),
        );
      },
    );
  });
}
