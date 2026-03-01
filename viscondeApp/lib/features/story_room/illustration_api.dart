import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart' as import_providers;
import '../auth/auth_controller.dart' as import_auth;
import 'models/illustration_models.dart';

class IllustrationApi {
  const IllustrationApi(this._dio);
  final Dio _dio;

  Future<List<ArtStyleModel>> listArtStyles(String token) async {
    try {
      final response = await _dio.get(
        '/v1/art-styles',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => ArtStyleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<StoryIllustrationModel?> getStoryIllustration(
    String token,
    String storyId,
    int stepIndex,
  ) async {
    try {
      final response = await _dio.get(
        '/v1/stories/$storyId/illustrations?stepIndex=$stepIndex',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['data'] == null) return null;
      return StoryIllustrationModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<StoryIllustrationModel> requestStoryIllustration(
    String token,
    String storyId,
    int stepIndex, {
    String? artStyleId,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/stories/$storyId/illustrations',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'stepIndex': stepIndex, 'artStyleId': artStyleId},
      );
      return StoryIllustrationModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}

final storyIllustrationProvider =
    FutureProvider.family<
      StoryIllustrationModel?,
      ({String storyId, int stepIndex})
    >((ref, arg) async {
      final token = ref.read(import_auth.authControllerProvider).accessToken;
      if (token == null) return null;
      final api = ref.watch(import_providers.illustrationApiProvider);

      try {
        var illustration = await api.getStoryIllustration(
          token,
          arg.storyId,
          arg.stepIndex,
        );
        illustration ??= await api.requestStoryIllustration(
          token,
          arg.storyId,
          arg.stepIndex,
        );
        return illustration;
      } catch (_) {
        return null;
      }
    });
