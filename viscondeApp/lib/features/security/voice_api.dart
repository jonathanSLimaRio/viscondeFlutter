import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import 'models/voice_models.dart';

class VoiceApi {
  const VoiceApi(this._dio);
  final Dio _dio;

  Future<List<VoiceProfileModel>> listProfiles({
    required String parentalUnlockToken,
  }) async {
    return withApiException(() async {
      final response = await _dio.get<List<dynamic>>(
        'voices',
        options: _parentalUnlockOptions(parentalUnlockToken),
      );
      final list = response.data ?? <dynamic>[];
      return list
          .map((e) => VoiceProfileModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<VoiceProfileModel> createProfile({
    required String name,
    String? relationship,
    required String parentalUnlockToken,
  }) async {
    return withApiException(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        'voices',
        data: {'name': name, 'relationship': relationship},
        options: _parentalUnlockOptions(parentalUnlockToken),
      );
      return VoiceProfileModel.fromJson(response.data ?? <String, dynamic>{});
    });
  }

  Future<void> trainProfile(
    String profileId, {
    required String parentalUnlockToken,
  }) async {
    await withApiException(() async {
      await _dio.post<Map<String, dynamic>>(
        'voices/$profileId/train',
        options: _parentalUnlockOptions(parentalUnlockToken),
      );
    });
  }

  Future<NarrationJobModel> requestNarration(
    String storyId,
    int stepIndex,
    String voiceProfileId,
  ) async {
    return withApiException(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        'stories/$storyId/narrate',
        data: {'stepIndex': stepIndex, 'voiceProfileId': voiceProfileId},
      );
      return NarrationJobModel.fromJson(response.data ?? <String, dynamic>{});
    });
  }

  Options _parentalUnlockOptions(String parentalUnlockToken) {
    return Options(headers: {'x-parental-unlock-token': parentalUnlockToken});
  }
}
