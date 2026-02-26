import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'models/story_models.dart';

class StoryStepSaveResult {
  const StoryStepSaveResult({
    required this.story,
    required this.idempotent,
  });

  final StorySessionModel story;
  final bool idempotent;
}

class StoryApi {
  StoryApi(this._dio);

  final Dio _dio;

  Future<StorySessionModel> createStorySession(
    String accessToken, {
    required String childProfileId,
    required String titleDraft,
    required String theme,
    required String scenario,
    required List<Map<String, String?>> characters,
    required String objective,
    required StoryMode startMode,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions',
      data: {
        'childProfileId': childProfileId,
        'titleDraft': titleDraft,
        'theme': theme,
        'scenario': scenario,
        'characters': characters,
        'objective': objective,
        'startMode': storyModeToApi(startMode),
      },
      options: authOptions(accessToken),
    );

    return StorySessionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StorySessionModel> getStorySession(
    String accessToken,
    String storyId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/story-sessions/$storyId',
      options: authOptions(accessToken),
    );

    return StorySessionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StorySessionModel> updateMode(
    String accessToken,
    String storyId,
    StoryMode mode,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/story-sessions/$storyId/mode',
      data: {
        'mode': storyModeToApi(mode),
      },
      options: authOptions(accessToken),
    );

    return StorySessionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StoryIdeasResult> requestIdeas(
    String accessToken,
    String storyId, {
    String? contextHint,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/ideas',
      data: {
        if (contextHint != null && contextHint.trim().isNotEmpty)
          'contextHint': contextHint.trim(),
      },
      options: authOptions(accessToken),
    );

    return StoryIdeasResult.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StoryStepSaveResult> createStep(
    String accessToken,
    String storyId, {
    required StoryStepKind kind,
    required int stepIndex,
    String? narratorText,
    String? narratorPrompt,
    String? selectedOptionId,
    String? selectedOptionLabel,
    required String localEventId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/steps',
      data: {
        'kind': storyStepKindToApi(kind),
        'stepIndex': stepIndex,
        if (narratorText != null && narratorText.trim().isNotEmpty)
          'narratorText': narratorText.trim(),
        if (narratorPrompt != null && narratorPrompt.trim().isNotEmpty)
          'narratorPrompt': narratorPrompt.trim(),
        if (selectedOptionId != null && selectedOptionId.trim().isNotEmpty)
          'selectedOptionId': selectedOptionId.trim(),
        if (selectedOptionLabel != null && selectedOptionLabel.trim().isNotEmpty)
          'selectedOptionLabel': selectedOptionLabel.trim(),
        'localEventId': localEventId,
      },
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    final storyPayload = payload['story'] as Map<String, dynamic>?;

    return StoryStepSaveResult(
      story: StorySessionModel.fromJson(storyPayload ?? <String, dynamic>{}),
      idempotent: (payload['idempotent'] as bool?) ?? false,
    );
  }

  Future<StorySessionModel> finalizeStory(
    String accessToken,
    String storyId, {
    String? titleFinal,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/finalize',
      data: {
        if (titleFinal != null && titleFinal.trim().isNotEmpty)
          'titleFinal': titleFinal.trim(),
      },
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    final storyPayload = payload['story'] as Map<String, dynamic>?;

    return StorySessionModel.fromJson(storyPayload ?? <String, dynamic>{});
  }

  Future<List<StoryListItem>> listStories(
    String accessToken, {
    String? childProfileId,
    StoryStatus? status,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/stories',
      queryParameters: {
        if (childProfileId != null && childProfileId.trim().isNotEmpty)
          'childProfileId': childProfileId.trim(),
        if (status != null) 'status': storyStatusToApi(status),
      },
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(StoryListItem.fromJson)
        .toList();
  }

  Future<StorySessionModel> getStory(String accessToken, String storyId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stories/$storyId',
      options: authOptions(accessToken),
    );

    return StorySessionModel.fromJson(response.data ?? <String, dynamic>{});
  }
}
