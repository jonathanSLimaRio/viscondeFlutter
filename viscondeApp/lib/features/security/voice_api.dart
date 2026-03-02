import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import 'models/voice_models.dart';

class VoiceApi {
  const VoiceApi(this._dio);
  final Dio _dio;

  Future<List<VoiceProfileModel>> listProfiles() async {
    return withApiException(() async {
      final response = await _dio.get<List<dynamic>>('/voices');
      final list = response.data ?? <dynamic>[];
      return list
          .map((e) => VoiceProfileModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<VoiceProfileModel> createProfile({
    required String name,
    String? relationship,
  }) async {
    return withApiException(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/voices',
        data: {'name': name, 'relationship': relationship},
      );
      return VoiceProfileModel.fromJson(response.data ?? <String, dynamic>{});
    });
  }

  Future<void> trainProfile(String profileId) async {
    await withApiException(() async {
      await _dio.post<Map<String, dynamic>>('/voices/$profileId/train');
    });
  }

  Future<NarrationJobModel> requestNarration(
    String storyId,
    int stepIndex,
    String voiceProfileId,
  ) async {
    return withApiException(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/stories/$storyId/narrate',
        data: {'stepIndex': stepIndex, 'voiceProfileId': voiceProfileId},
      );
      return NarrationJobModel.fromJson(response.data ?? <String, dynamic>{});
    });
  }
}
