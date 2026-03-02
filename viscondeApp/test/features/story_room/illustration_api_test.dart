import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/core/network/api_exception.dart';
import 'package:visconde_app/features/story_room/illustration_api.dart';

import '../../helpers/fake_dio_adapter.dart';

void main() {
  group('IllustrationApi', () {
    test('listArtStyles returns styles on success payload', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        captured = options;
        return jsonResponse([
          {'id': 'style-1', 'name': 'Aquarela', 'promptTemplate': 'watercolor'},
        ]);
      });

      final api = IllustrationApi(dio);
      final result = await api.listArtStyles();

      expect(captured?.path, '/art-styles');
      expect(result, hasLength(1));
      expect(result.first.id, 'style-1');
    });

    test(
      'requestStoryIllustration uses raw payload contract endpoint',
      () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        dio.httpClientAdapter = FakeDioAdapter((options) async {
          captured = options;
          return jsonResponse({
            'id': 'ill-1',
            'storyId': 'story-1',
            'stepIndex': 2,
            'status': 'COMPLETED',
            'imageUrl': 'https://cdn.test/scene.png',
          });
        });

        final api = IllustrationApi(dio);
        final result = await api.requestStoryIllustration(
          'story-1',
          2,
          artStyleId: 'style-1',
        );

        expect(captured?.path, '/stories/story-1/illustrations');
        expect(captured?.data, {'stepIndex': 2, 'artStyleId': 'style-1'});
        expect(result.id, 'ill-1');
        expect(result.status, 'COMPLETED');
      },
    );

    test('listArtStyles maps 401 into unauthorized ApiException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((_) async {
        return jsonResponse({'message': 'Sessao expirada'}, statusCode: 401);
      });

      final api = IllustrationApi(dio);

      await expectLater(
        api.listArtStyles(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('listArtStyles maps 500 into server ApiException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((_) async {
        return jsonResponse({'message': 'Falha interna'}, statusCode: 500);
      });

      final api = IllustrationApi(dio);

      await expectLater(
        api.listArtStyles(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.server)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('listArtStyles maps timeout into timeout ApiException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = FakeDioAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      });

      final api = IllustrationApi(dio);

      await expectLater(
        api.listArtStyles(),
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
      'listArtStyles wraps payload mismatch as unknown ApiException',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        dio.httpClientAdapter = FakeDioAdapter((_) async {
          return jsonResponse(['invalid']);
        });

        final api = IllustrationApi(dio);

        await expectLater(
          api.listArtStyles(),
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
