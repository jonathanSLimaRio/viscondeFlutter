import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'models/admin_models.dart';

class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  Future<List<AdminThemeModel>> listThemes(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      '/admin/themes',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminThemeModel.fromJson)
        .toList();
  }

  Future<AdminThemeModel> createTheme(
    String accessToken, {
    required String name,
    required String shortDescription,
    required String iconKey,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/themes',
      data: {
        'name': name,
        'shortDescription': shortDescription,
        'iconKey': iconKey,
        'sortOrder': sortOrder,
        'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminThemeModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AdminThemeModel> updateTheme(
    String accessToken,
    String themeId, {
    String? name,
    String? shortDescription,
    String? iconKey,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/themes/$themeId',
      data: {
        if (name != null) 'name': name,
        if (shortDescription != null) 'shortDescription': shortDescription,
        if (iconKey != null) 'iconKey': iconKey,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (isActive != null) 'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminThemeModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<AdminVirtueModel>> listVirtues(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      '/admin/virtues',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminVirtueModel.fromJson)
        .toList();
  }

  Future<AdminVirtueModel> createVirtue(
    String accessToken, {
    required String name,
    required String shortDescription,
    required String iconKey,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/virtues',
      data: {
        'name': name,
        'shortDescription': shortDescription,
        'iconKey': iconKey,
        'sortOrder': sortOrder,
        'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminVirtueModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AdminVirtueModel> updateVirtue(
    String accessToken,
    String virtueId, {
    String? name,
    String? shortDescription,
    String? iconKey,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/virtues/$virtueId',
      data: {
        if (name != null) 'name': name,
        if (shortDescription != null) 'shortDescription': shortDescription,
        if (iconKey != null) 'iconKey': iconKey,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (isActive != null) 'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminVirtueModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<AdminVirtueTemplateModel>> listVirtueTemplates(
    String accessToken, {
    String? virtueId,
    String? ageBand,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/admin/virtue-templates',
      queryParameters: {
        if (virtueId != null && virtueId.isNotEmpty) 'virtueId': virtueId,
        if (ageBand != null && ageBand.isNotEmpty) 'ageBand': ageBand,
      },
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminVirtueTemplateModel.fromJson)
        .toList();
  }

  Future<AdminVirtueTemplateModel> createVirtueTemplate(
    String accessToken, {
    required String virtueId,
    required String ageBand,
    required String dilemmaText,
    required String endQuestionText,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/virtue-templates',
      data: {
        'virtueId': virtueId,
        'ageBand': ageBand,
        'dilemmaText': dilemmaText,
        'endQuestionText': endQuestionText,
        'sortOrder': sortOrder,
        'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminVirtueTemplateModel.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminVirtueTemplateModel> updateVirtueTemplate(
    String accessToken,
    String templateId, {
    String? dilemmaText,
    String? endQuestionText,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/virtue-templates/$templateId',
      data: {
        if (dilemmaText != null) 'dilemmaText': dilemmaText,
        if (endQuestionText != null) 'endQuestionText': endQuestionText,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (isActive != null) 'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminVirtueTemplateModel.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<List<AdminPromptModel>> listPrompts(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      '/admin/prompts',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminPromptModel.fromJson)
        .toList();
  }

  Future<AdminPromptModel> createPrompt(
    String accessToken, {
    required String key,
    required AdminPromptKind kind,
    required String title,
    required String text,
    String? themeId,
    String? virtueId,
    String? ageBand,
    String? mode,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/prompts',
      data: {
        'key': key,
        'kind': adminPromptKindToApi(kind),
        'title': title,
        'text': text,
        if (themeId != null && themeId.isNotEmpty) 'themeId': themeId,
        if (virtueId != null && virtueId.isNotEmpty) 'virtueId': virtueId,
        if (ageBand != null) 'ageBand': ageBand,
        if (mode != null) 'mode': mode,
        'sortOrder': sortOrder,
        'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminPromptModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AdminPromptModel> updatePrompt(
    String accessToken,
    String promptId, {
    String? key,
    AdminPromptKind? kind,
    String? title,
    String? text,
    String? themeId,
    String? virtueId,
    String? ageBand,
    String? mode,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/prompts/$promptId',
      data: {
        if (key != null) 'key': key,
        if (kind != null) 'kind': adminPromptKindToApi(kind),
        if (title != null) 'title': title,
        if (text != null) 'text': text,
        if (themeId != null) 'themeId': themeId,
        if (virtueId != null) 'virtueId': virtueId,
        if (ageBand != null) 'ageBand': ageBand,
        if (mode != null) 'mode': mode,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (isActive != null) 'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminPromptModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<AdminStoryTemplateListItem>> listStoryTemplates(
    String accessToken,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      '/admin/story-templates',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminStoryTemplateListItem.fromJson)
        .toList();
  }

  Future<AdminStoryTemplateListItem> createStoryTemplate(
    String accessToken, {
    String? slug,
    required String title,
    required String description,
    String? themeId,
    String? virtueId,
    String? ageBand,
    required String defaultScenario,
    required String defaultObjective,
    bool isActive = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/story-templates',
      data: {
        if (slug != null && slug.isNotEmpty) 'slug': slug,
        'title': title,
        'description': description,
        if (themeId != null && themeId.isNotEmpty) 'themeId': themeId,
        'defaultScenario': defaultScenario,
        'defaultObjective': defaultObjective,
        if (virtueId != null) 'virtueId': virtueId,
        if (ageBand != null) 'ageBand': ageBand,
        'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminStoryTemplateListItem.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminStoryTemplateDetail> getStoryTemplate(
    String accessToken,
    String templateId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/story-templates/$templateId',
      options: authOptions(accessToken),
    );

    return AdminStoryTemplateDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminStoryTemplateDetail> updateStoryTemplate(
    String accessToken,
    String templateId, {
    String? slug,
    String? title,
    String? description,
    String? themeId,
    String? virtueId,
    String? ageBand,
    String? defaultScenario,
    String? defaultObjective,
    bool? isActive,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/admin/story-templates/$templateId',
      data: {
        if (slug != null) 'slug': slug,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (themeId != null) 'themeId': themeId,
        if (virtueId != null) 'virtueId': virtueId,
        if (ageBand != null) 'ageBand': ageBand,
        if (defaultScenario != null) 'defaultScenario': defaultScenario,
        if (defaultObjective != null) 'defaultObjective': defaultObjective,
        if (isActive != null) 'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminStoryTemplateDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminStoryTemplateDetail> addStoryTemplateCharacter(
    String accessToken,
    String templateId, {
    required String name,
    String? role,
    int? sortOrder,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/story-templates/$templateId/characters',
      data: {
        'name': name,
        if (role != null && role.isNotEmpty) 'role': role,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      options: authOptions(accessToken),
    );

    return AdminStoryTemplateDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminStoryTemplateDetail> addStoryTemplateNode(
    String accessToken,
    String templateId, {
    required String nodeKey,
    required AdminStoryTemplateNodeKind kind,
    required String title,
    String? narratorText,
    String? promptHint,
    int? sortOrder,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/story-templates/$templateId/nodes',
      data: {
        'nodeKey': nodeKey,
        'kind': adminStoryTemplateNodeKindToApi(kind),
        'title': title,
        if (narratorText != null && narratorText.isNotEmpty)
          'narratorText': narratorText,
        if (promptHint != null && promptHint.isNotEmpty)
          'promptHint': promptHint,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      options: authOptions(accessToken),
    );

    return AdminStoryTemplateDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminStoryTemplateDetail> updateStoryTemplateNode(
    String accessToken,
    String templateId,
    String nodeId, {
    String? nodeKey,
    AdminStoryTemplateNodeKind? kind,
    String? title,
    String? narratorText,
    String? promptHint,
    int? sortOrder,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/story-templates/$templateId/nodes/$nodeId',
      data: {
        if (nodeKey != null) 'nodeKey': nodeKey,
        if (kind != null) 'kind': adminStoryTemplateNodeKindToApi(kind),
        if (title != null) 'title': title,
        if (narratorText != null) 'narratorText': narratorText,
        if (promptHint != null) 'promptHint': promptHint,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      options: authOptions(accessToken),
    );

    return AdminStoryTemplateDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminStoryTemplateDetail> addStoryTemplateOption(
    String accessToken,
    String templateId, {
    required String nodeId,
    required String optionKey,
    required String label,
    required String nextNodeId,
    int? sortOrder,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/story-templates/$templateId/options',
      data: {
        'nodeId': nodeId,
        'optionKey': optionKey,
        'label': label,
        'nextNodeId': nextNodeId,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      options: authOptions(accessToken),
    );

    return AdminStoryTemplateDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminStoryTemplateDetail> updateStoryTemplateOption(
    String accessToken,
    String templateId,
    String optionId, {
    String? optionKey,
    String? label,
    String? nextNodeId,
    int? sortOrder,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/story-templates/$templateId/options/$optionId',
      data: {
        if (optionKey != null) 'optionKey': optionKey,
        if (label != null) 'label': label,
        if (nextNodeId != null) 'nextNodeId': nextNodeId,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      options: authOptions(accessToken),
    );

    return AdminStoryTemplateDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminTemplateValidationResult> validateStoryTemplate(
    String accessToken,
    String templateId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/story-templates/$templateId/validate',
      options: authOptions(accessToken),
    );

    return AdminTemplateValidationResult.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> publishStoryTemplate(
    String accessToken,
    String templateId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/story-templates/$templateId/publish',
      options: authOptions(accessToken),
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<List<AdminModerationTermModel>> listModerationTerms(
    String accessToken,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      '/admin/moderation/terms',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminModerationTermModel.fromJson)
        .toList();
  }

  Future<AdminModerationTermModel> createModerationTerm(
    String accessToken, {
    required String displayTerm,
    required AdminModerationPolicy policy,
    required AdminModerationScope scope,
    String? replacement,
    bool isActive = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/moderation/terms',
      data: {
        'displayTerm': displayTerm,
        'policy': adminModerationPolicyToApi(policy),
        'scope': adminModerationScopeToApi(scope),
        if (replacement != null && replacement.isNotEmpty)
          'replacement': replacement,
        'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminModerationTermModel.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<AdminModerationTermModel> updateModerationTerm(
    String accessToken,
    String termId, {
    String? displayTerm,
    AdminModerationPolicy? policy,
    AdminModerationScope? scope,
    String? replacement,
    bool? isActive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/moderation/terms/$termId',
      data: {
        if (displayTerm != null) 'displayTerm': displayTerm,
        if (policy != null) 'policy': adminModerationPolicyToApi(policy),
        if (scope != null) 'scope': adminModerationScopeToApi(scope),
        if (replacement != null) 'replacement': replacement,
        if (isActive != null) 'isActive': isActive,
      },
      options: authOptions(accessToken),
    );

    return AdminModerationTermModel.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }
}
