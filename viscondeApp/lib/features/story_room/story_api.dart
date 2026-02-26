import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'models/story_models.dart';

class StoryStepSaveResult {
  const StoryStepSaveResult({required this.story, required this.idempotent});

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
    String? virtueId,
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
        if (virtueId != null && virtueId.trim().isNotEmpty)
          'virtueId': virtueId.trim(),
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
      data: {'mode': storyModeToApi(mode)},
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
        if (selectedOptionLabel != null &&
            selectedOptionLabel.trim().isNotEmpty)
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

  Future<List<VirtueModel>> listVirtues(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      '/virtues',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(VirtueModel.fromJson)
        .toList();
  }

  Future<VirtueSuggestionResult> suggestVirtue(
    String accessToken, {
    required String childProfileId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/virtues/suggest',
      queryParameters: {'childProfileId': childProfileId},
      options: authOptions(accessToken),
    );

    return VirtueSuggestionResult.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<VirtueReportOverviewResult> fetchVirtueReportOverview(
    String accessToken, {
    required String parentalUnlockToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/virtues/reports/overview',
      options: authOptions(accessToken).copyWith(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-parental-unlock-token': parentalUnlockToken,
        },
      ),
    );

    return VirtueReportOverviewResult.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<VirtueChildSummaryResult> fetchVirtueChildSummary(
    String accessToken, {
    required String childId,
    required String parentalUnlockToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/virtues/reports/children/$childId/summary',
      options: authOptions(accessToken).copyWith(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-parental-unlock-token': parentalUnlockToken,
        },
      ),
    );

    return VirtueChildSummaryResult.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<RemoteOpenResult> openRemoteRoom(
    String accessToken,
    String storyId, {
    required String parentalUnlockToken,
    RemoteCallMode callMode = RemoteCallMode.audio,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/remote/open',
      data: {'callMode': remoteCallModeToApi(callMode)},
      options: authOptions(accessToken).copyWith(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-parental-unlock-token': parentalUnlockToken,
        },
      ),
    );

    return RemoteOpenResult.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<RemoteOpenResult> regenerateRemoteCode(
    String accessToken,
    String storyId, {
    required String parentalUnlockToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/remote/code/regenerate',
      options: authOptions(accessToken).copyWith(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-parental-unlock-token': parentalUnlockToken,
        },
      ),
    );

    return RemoteOpenResult.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> closeRemoteRoom(String accessToken, String storyId) async {
    await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/remote/close',
      options: authOptions(accessToken),
    );
  }

  Future<RemoteRoomStateResult> getRemoteRoomState(
    String accessToken,
    String storyId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/story-sessions/$storyId/remote/state',
      options: authOptions(accessToken),
    );

    return RemoteRoomStateResult.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<RemoteJoinResult> joinRemoteRoomByCode({
    required String code,
    required String displayName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/remote/join',
      data: {
        'code': code,
        'displayName': displayName,
      },
    );

    return RemoteJoinResult.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StoryStepSaveResult> createRemoteGuestStep(
    String participantToken,
    String storyId, {
    required int stepIndex,
    required String selectedOptionLabel,
    String? selectedOptionId,
    required String localEventId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/remote/steps',
      data: {
        'kind': 'CHILD_CHOICE',
        'stepIndex': stepIndex,
        'selectedOptionLabel': selectedOptionLabel,
        if (selectedOptionId != null && selectedOptionId.trim().isNotEmpty)
          'selectedOptionId': selectedOptionId.trim(),
        'localEventId': localEventId,
      },
      options: authOptions(participantToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    final storyPayload = payload['story'] as Map<String, dynamic>?;

    return StoryStepSaveResult(
      story: StorySessionModel.fromJson(storyPayload ?? <String, dynamic>{}),
      idempotent: (payload['idempotent'] as bool?) ?? false,
    );
  }

  Future<StoryInteractionModel> createRemoteChat(
    String bearerToken,
    String storyId, {
    required String messageText,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/remote/chat',
      data: {'messageText': messageText},
      options: authOptions(bearerToken),
    );

    return StoryInteractionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StoryInteractionModel> createRemoteReaction(
    String bearerToken,
    String storyId, {
    required String emoji,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/story-sessions/$storyId/remote/reactions',
      data: {'emoji': emoji},
      options: authOptions(bearerToken),
    );

    return StoryInteractionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StoryInteractionsResult> getStoryInteractions(
    String accessToken,
    String storyId, {
    required String parentalUnlockToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stories/$storyId/interactions',
      options: authOptions(accessToken).copyWith(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-parental-unlock-token': parentalUnlockToken,
        },
      ),
    );

    return StoryInteractionsResult.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }
}
