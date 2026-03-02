import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../../shared/providers.dart' as import_providers;
import 'models/illustration_models.dart';

class IllustrationApi {
  const IllustrationApi(this._dio);
  final Dio _dio;

  Future<List<ArtStyleModel>> listArtStyles() async {
    return withApiException(() async {
      final response = await _dio.get<List<dynamic>>('/art-styles');
      final list = response.data ?? <dynamic>[];
      return list
          .map((e) => ArtStyleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<StoryIllustrationModel?> getStoryIllustration(
    String storyId,
    int stepIndex,
  ) async {
    return withApiException(() async {
      final response = await _dio.get<Map<String, dynamic>?>(
        '/stories/$storyId/illustrations',
        queryParameters: {'stepIndex': stepIndex},
      );
      if (response.data == null) return null;
      return StoryIllustrationModel.fromJson(
        response.data ?? <String, dynamic>{},
      );
    });
  }

  Future<StoryIllustrationModel> requestStoryIllustration(
    String storyId,
    int stepIndex, {
    String? artStyleId,
  }) async {
    return withApiException(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/stories/$storyId/illustrations',
        data: {'stepIndex': stepIndex, 'artStyleId': artStyleId},
      );
      return StoryIllustrationModel.fromJson(
        response.data ?? <String, dynamic>{},
      );
    });
  }
}

final storyIllustrationProvider =
    FutureProvider.family<
      StoryIllustrationModel?,
      ({String storyId, int stepIndex})
    >((ref, arg) async {
      final api = ref.watch(import_providers.illustrationApiProvider);

      try {
        var illustration = await api.getStoryIllustration(
          arg.storyId,
          arg.stepIndex,
        );
        illustration ??= await api.requestStoryIllustration(
          arg.storyId,
          arg.stepIndex,
        );
        return illustration;
      } catch (error) {
        if (error is ApiException && error.kind == ApiErrorKind.unauthorized) {
          return null;
        }
        return null;
      }
    });
