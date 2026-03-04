import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../gamification/models/gamification_models.dart';
import 'models/story_models.dart';

class StoryStepSaveResult {
  const StoryStepSaveResult({required this.story, required this.idempotent});

  final StorySessionModel story;
  final bool idempotent;
}

class StoryCoopVoteResult {
  const StoryCoopVoteResult({
    required this.isVoteLogged,
    required this.allVoted,
    this.stepResult,
    this.participantId,
  });

  final bool isVoteLogged;
  final bool allVoted;
  final StoryStepSaveResult? stepResult;
  final String? participantId;

  factory StoryCoopVoteResult.fromJson(Map<String, dynamic> json) {
    StoryStepSaveResult? stepResult;
    if (json['stepResult'] != null) {
      final payload = json['stepResult'] as Map<String, dynamic>;
      final storyPayload = payload['story'] as Map<String, dynamic>?;
      if (storyPayload != null) {
        stepResult = StoryStepSaveResult(
          story: StorySessionModel.fromJson(storyPayload),
          idempotent: (payload['idempotent'] as bool?) ?? false,
        );
      }
    }

    return StoryCoopVoteResult(
      isVoteLogged: (json['isVoteLogged'] as bool?) ?? false,
      allVoted: (json['allVoted'] as bool?) ?? false,
      participantId: json['participantId'] as String?,
      stepResult: stepResult,
    );
  }
}

class StoryFinalizeResult {
  const StoryFinalizeResult({
    required this.story,
    this.gamification,
    this.publishMeta,
  });

  final StorySessionModel story;
  final PublishGamificationSummaryModel? gamification;
  final StoryPublishMetaModel? publishMeta;
}

class StoryApi {
  StoryApi(this._dio);

  final Dio _dio;

  String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

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
    String? sourceTemplateId,
    String? artStyleId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'story-sessions',
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
        if (sourceTemplateId != null && sourceTemplateId.trim().isNotEmpty)
          'sourceTemplateId': sourceTemplateId.trim(),
        if (artStyleId != null && artStyleId.trim().isNotEmpty)
          'artStyleId': artStyleId.trim(),
      },
      options: authOptions(accessToken),
    );

    return StorySessionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StorySessionModel> updateStorySessionSetup(
    String accessToken,
    String storyId, {
    required String titleDraft,
    required String theme,
    required String scenario,
    required String objective,
    required List<Map<String, String?>> characters,
    String? virtueId,
    String? sourceTemplateId,
    bool updateSourceTemplate = false,
    String? artStyleId,
    bool updateArtStyle = false,
    StoryMode? mode,
    bool applyAutoVirtue = false,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'story-sessions/$storyId',
      data: {
        'titleDraft': titleDraft,
        'theme': theme,
        'scenario': scenario,
        'objective': objective,
        'characters': characters,
        if (applyAutoVirtue)
          'virtueId': null
        else if (virtueId != null && virtueId.trim().isNotEmpty)
          'virtueId': virtueId.trim(),
        if (updateSourceTemplate) 'sourceTemplateId': sourceTemplateId?.trim(),
        if (updateArtStyle) 'artStyleId': artStyleId?.trim(),
        if (mode != null) 'mode': storyModeToApi(mode),
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
      'story-sessions/$storyId',
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
      'story-sessions/$storyId/mode',
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
      'story-sessions/$storyId/ideas',
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
    int? gameNodeIndex,
    StoryGameActionModel? gameAction,
    required String localEventId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'story-sessions/$storyId/steps',
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
        'gameNodeIndex': ?gameNodeIndex,
        if (gameAction != null)
          'gameAction': {'key': gameAction.key, 'label': gameAction.label},
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

  Future<StoryFinalizeResult> finalizeStory(
    String accessToken,
    String storyId, {
    String? titleFinal,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'story-sessions/$storyId/finalize',
      data: {
        if (titleFinal != null && titleFinal.trim().isNotEmpty)
          'titleFinal': titleFinal.trim(),
      },
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    final storyPayload = payload['story'] as Map<String, dynamic>?;
    final gamificationPayload =
        payload['gamification'] as Map<String, dynamic>?;
    final publishMetaPayload = payload['publishMeta'] as Map<String, dynamic>?;

    return StoryFinalizeResult(
      story: StorySessionModel.fromJson(storyPayload ?? <String, dynamic>{}),
      gamification: gamificationPayload == null
          ? null
          : PublishGamificationSummaryModel.fromJson(gamificationPayload),
      publishMeta: publishMetaPayload == null
          ? null
          : StoryPublishMetaModel.fromJson(publishMetaPayload),
    );
  }

  Future<StoryFinalizeResult> wizardPublishStory(
    String accessToken,
    String storyId, {
    String? titleFinal,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'story-sessions/$storyId/wizard-publish',
      data: {
        if (titleFinal != null && titleFinal.trim().isNotEmpty)
          'titleFinal': titleFinal.trim(),
      },
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    final storyPayload = payload['story'] as Map<String, dynamic>?;
    final gamificationPayload =
        payload['gamification'] as Map<String, dynamic>?;
    final publishMetaPayload = payload['publishMeta'] as Map<String, dynamic>?;

    return StoryFinalizeResult(
      story: StorySessionModel.fromJson(storyPayload ?? <String, dynamic>{}),
      gamification: gamificationPayload == null
          ? null
          : PublishGamificationSummaryModel.fromJson(gamificationPayload),
      publishMeta: publishMetaPayload == null
          ? null
          : StoryPublishMetaModel.fromJson(publishMetaPayload),
    );
  }

  Future<List<StoryListItem>> listStories(
    String accessToken, {
    String? childProfileId,
    StoryStatus? status,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      'stories',
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

  Future<List<StoryVaultCollectionItem>> listStoryVaultCollections(
    String accessToken, {
    String? childProfileId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? theme,
    String? virtueId,
    bool favoriteOnly = false,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      'story-vault/collections',
      queryParameters: {
        if (childProfileId != null && childProfileId.trim().isNotEmpty)
          'childProfileId': childProfileId.trim(),
        if (dateFrom != null) 'dateFrom': _formatDateOnly(dateFrom),
        if (dateTo != null) 'dateTo': _formatDateOnly(dateTo),
        if (theme != null && theme.trim().isNotEmpty) 'theme': theme.trim(),
        if (virtueId != null && virtueId.trim().isNotEmpty)
          'virtueId': virtueId.trim(),
        if (favoriteOnly) 'favoriteOnly': 'true',
      },
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(StoryVaultCollectionItem.fromJson)
        .toList();
  }

  Future<StoryVaultCollectionDetail> getStoryVaultCollection(
    String accessToken,
    String collectionId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'story-vault/collections/$collectionId',
      options: authOptions(accessToken),
    );

    return StoryVaultCollectionDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<bool> setStoryVaultFavorite(
    String accessToken,
    String collectionId, {
    required bool isFavorite,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'story-vault/collections/$collectionId/favorite',
      data: {'isFavorite': isFavorite},
      options: authOptions(accessToken),
    );

    return (response.data?['isFavorite'] as bool?) ?? isFavorite;
  }

  Future<StorySessionModel> continueStory(
    String accessToken,
    String storyId, {
    String? titleDraft,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'stories/$storyId/continue',
      data: {
        if (titleDraft != null && titleDraft.trim().isNotEmpty)
          'titleDraft': titleDraft.trim(),
      },
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    return StorySessionModel.fromJson(
      (payload['story'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  Future<StorySessionModel> duplicateStoryAsTemplate(
    String accessToken,
    String storyId, {
    String? childProfileId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'stories/$storyId/duplicate-template',
      data: {
        if (childProfileId != null && childProfileId.trim().isNotEmpty)
          'childProfileId': childProfileId.trim(),
      },
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    return StorySessionModel.fromJson(
      (payload['story'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  Future<StorySessionModel> getStory(String accessToken, String storyId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'stories/$storyId',
      options: authOptions(accessToken),
    );

    return StorySessionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<VirtueModel>> listVirtues(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      'virtues',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(VirtueModel.fromJson)
        .toList();
  }

  Future<List<ContentStoryTemplateModel>> listPublishedStoryTemplates(
    String accessToken,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      'content/story-templates',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ContentStoryTemplateModel.fromJson)
        .toList();
  }

  Future<StoryTemplatePrefillModel> getStoryTemplatePrefill(
    String accessToken,
    String templateId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'content/story-templates/$templateId/prefill',
      options: authOptions(accessToken),
    );

    return StoryTemplatePrefillModel.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<VirtueSuggestionResult> suggestVirtue(
    String accessToken, {
    required String childProfileId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'virtues/suggest',
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
      'virtues/reports/overview',
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
      'virtues/reports/children/$childId/summary',
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
      'story-sessions/$storyId/remote/open',
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
      'story-sessions/$storyId/remote/code/regenerate',
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
      'story-sessions/$storyId/remote/close',
      options: authOptions(accessToken),
    );
  }

  Future<RemoteRoomStateResult> getRemoteRoomState(
    String accessToken,
    String storyId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'story-sessions/$storyId/remote/state',
      options: authOptions(accessToken),
    );

    return RemoteRoomStateResult.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<RemoteJoinResult> joinRemoteRoomByCode({
    required String code,
    required String displayName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'story-sessions/remote/join',
      data: {'code': code, 'displayName': displayName},
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
      'story-sessions/$storyId/remote/steps',
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

  Future<StoryCoopVoteResult> createCoopVote(
    String participantToken,
    String storyId, {
    required int stepIndex,
    required String selectedOptionLabel,
    required String selectedOptionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'story-sessions/$storyId/remote/votes',
      data: {
        'stepIndex': stepIndex,
        'optionId': selectedOptionId.trim(),
        'optionLabel': selectedOptionLabel,
      },
      options: authOptions(participantToken),
    );

    return StoryCoopVoteResult.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<StoryInteractionModel> createRemoteChat(
    String bearerToken,
    String storyId, {
    required String messageText,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'story-sessions/$storyId/remote/chat',
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
      'story-sessions/$storyId/remote/reactions',
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
      'stories/$storyId/interactions',
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
