import 'package:dio/dio.dart';
import '../../../shared/api_error.dart';
import 'models/voice_models.dart';

class VoiceApi {
  const VoiceApi(this._dio);
  final Dio _dio;

  Future<List<VoiceProfileModel>> listProfiles(String token) async {
    try {
      final response = await _dio.get(
        '/v1/voices',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => VoiceProfileModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<VoiceProfileModel> createProfile(
    String token, {
    required String name,
    String? relationship,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/voices',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'name': name, 'relationship': relationship},
      );
      return VoiceProfileModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<void> trainProfile(String token, String profileId) async {
    try {
      await _dio.post(
        '/v1/voices/$profileId/train',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<NarrationJobModel> requestNarration(
    String token,
    String storyId,
    int stepIndex,
    String voiceProfileId,
  ) async {
    try {
      final response = await _dio.post(
        '/v1/stories/$storyId/narrate',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'stepIndex': stepIndex, 'voiceProfileId': voiceProfileId},
      );
      return NarrationJobModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
