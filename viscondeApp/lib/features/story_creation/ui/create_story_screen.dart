import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/logging/app_logger.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/app_feedback.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';
import '../../gamification/game_adventure_session_controller.dart';
import '../../story_creation/create_story_wizard_draft_store.dart';
import '../../story_creation/quick_story_defaults.dart';
import '../../story_room/models/story_models.dart';
import '../../story_room/story_room_controller.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key, this.resumeDraft = false});

  final bool resumeDraft;

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _titleController = TextEditingController();
  final _themeController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _charactersController = TextEditingController();

  List<ChildProfile> _children = const [];
  List<StoryVaultCollectionItem> _recentCollections = const [];
  List<VirtueModel> _virtues = const [];
  List<ContentStoryTemplateModel> _templates = const [];
  String? _storyId;
  String? _selectedChildId;
  String? _selectedVirtueId;
  String? _selectedTemplateId;
  String? _selectedArtStyleId;
  String? _suggestionReason;
  String? _recommendationFeedback;

  StoryMode _mode = StoryMode.parentNarrator;

  bool _loadingChildren = false;
  bool _loadingVirtues = false;
  bool _loadingTemplates = false;
  bool _loadingArtStyles = false;
  bool _loadingCollections = false;
  bool _applyingTemplate = false;
  bool _busyAction = false;
  bool _bootstrapLoading = true;
  bool _flowCompleted = false;

  DateTime _stepStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    if (!_flowCompleted) {
      final durationMs = DateTime.now()
          .difference(_stepStartedAt)
          .inMilliseconds;
      UxAnalytics.log(
        'story_create_abandoned',
        params: <String, Object?>{
          'step': 1,
          'child_id': _selectedChildId,
          'source': 'create_story_screen',
          'flow': 'wizard',
          'duration_ms': durationMs,
        },
      );
    }

    _titleController.dispose();
    _themeController.dispose();
    _scenarioController.dispose();
    _objectiveController.dispose();
    _charactersController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    UxAnalytics.log(
      'story_create_started',
      params: const <String, Object?>{
        'source': 'create_story_screen',
        'flow': 'wizard',
      },
    );

    await Future.wait<void>([
      _loadChildren(showError: false),
      _loadRecentCollections(showError: false),
      _loadVirtues(showError: false),
      _loadTemplates(showError: false),
      _loadArtStyles(showError: false),
    ]);

    if (!mounted) {
      return;
    }

    if (widget.resumeDraft) {
      await _restoreDraftIfAvailable();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _bootstrapLoading = false;
      _stepStartedAt = DateTime.now();
    });
  }

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  Future<void> _restoreDraftIfAvailable() async {
    final userId = ref.read(authControllerProvider).user?.id;
    final token = _accessToken();
    if (userId == null || token == null) {
      return;
    }

    final store = ref.read(createStoryWizardDraftStoreProvider);
    CreateStoryWizardDraft? draft;
    try {
      draft = await store.read(userId);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao ler rascunho local do wizard.',
        error: error,
        stackTrace: stackTrace,
        scope: 'story_creation',
      );
      draft = null;
    }
    if (draft == null) {
      return;
    }

    StorySessionModel? session;
    if (draft.storyId != null && draft.storyId!.isNotEmpty) {
      try {
        session = await ref
            .read(storyApiProvider)
            .getStorySession(token, draft.storyId!);
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Falha ao carregar sessão para retomar wizard. Limpando rascunho local.',
          error: error,
          stackTrace: stackTrace,
          scope: 'story_creation',
        );
        try {
          await store.clear(userId);
        } catch (clearError, clearStackTrace) {
          AppLogger.warn(
            'Falha ao limpar rascunho local após erro de retomada.',
            error: clearError,
            stackTrace: clearStackTrace,
            scope: 'story_creation',
          );
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _storyId = draft?.storyId;
      _selectedChildId = draft?.selectedChildId;
      _selectedVirtueId = draft?.selectedVirtueId;
      _selectedTemplateId = draft?.selectedTemplateId;
      _selectedArtStyleId = draft?.selectedArtStyleId;
      _mode = draft?.mode ?? StoryMode.parentNarrator;
      _titleController.text = draft?.titleDraft ?? '';
      _themeController.text = draft?.theme ?? '';
      _scenarioController.text = draft?.scenario ?? '';
      _objectiveController.text = draft?.objective ?? '';
      _charactersController.text = draft?.characters ?? '';

      if (session != null) {
        _applySessionToForm(session, replaceText: false);
      }
    });
  }

  void _applySessionToForm(
    StorySessionModel session, {
    bool replaceText = true,
  }) {
    _storyId = session.id;
    _selectedChildId ??= session.childProfileId;
    _selectedVirtueId = session.virtue?.id ?? _selectedVirtueId;
    _selectedTemplateId = session.sourceTemplateId ?? _selectedTemplateId;
    _selectedArtStyleId = session.artStyleId ?? _selectedArtStyleId;
    _mode = session.currentMode;

    if (replaceText || _titleController.text.trim().isEmpty) {
      _titleController.text = session.titleDraft;
    }
    if (replaceText || _themeController.text.trim().isEmpty) {
      _themeController.text = session.theme;
    }
    if (replaceText || _scenarioController.text.trim().isEmpty) {
      _scenarioController.text = session.scenario;
    }
    if (replaceText || _objectiveController.text.trim().isEmpty) {
      _objectiveController.text = session.objective;
    }

    final existingCharacters = session.characters
        .map((character) => character.name.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
    if (replaceText || _charactersController.text.trim().isEmpty) {
      _charactersController.text = existingCharacters;
    }
  }

  Future<void> _loadChildren({bool showError = true}) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loadingChildren = true);

    try {
      final children = await ref.read(childrenApiProvider).listChildren(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _children = children;
        _selectedChildId =
            _selectedChildId ??
            (children.isNotEmpty ? children.first.id : null);
      });
    } catch (error) {
      if (!mounted || !showError) {
        return;
      }
      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _loadingChildren = false);
      }
    }
  }

  Future<void> _loadVirtues({bool showError = true}) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loadingVirtues = true);

    try {
      final virtues = await ref.read(storyApiProvider).listVirtues(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _virtues = virtues;
        _selectedVirtueId =
            _selectedVirtueId ?? (virtues.isNotEmpty ? virtues.first.id : null);
      });
    } catch (error) {
      if (!mounted || !showError) {
        return;
      }
      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _loadingVirtues = false);
      }
    }
  }

  Future<void> _loadRecentCollections({bool showError = true}) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loadingCollections = true);

    try {
      final collections = await ref
          .read(storyApiProvider)
          .listStoryVaultCollections(token);
      if (!mounted) {
        return;
      }

      final sortedCollections = List<StoryVaultCollectionItem>.from(collections)
        ..sort(
          (left, right) =>
              right.lastReferenceAt.compareTo(left.lastReferenceAt),
        );
      setState(() {
        _recentCollections = sortedCollections;
      });
    } catch (error) {
      if (!mounted || !showError) {
        return;
      }
      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _loadingCollections = false);
      }
    }
  }

  Future<void> _loadTemplates({bool showError = true}) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loadingTemplates = true);

    try {
      final templates = await ref
          .read(storyApiProvider)
          .listPublishedStoryTemplates(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _templates = templates;
      });
    } catch (error) {
      if (!mounted || !showError) {
        return;
      }
      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _loadingTemplates = false);
      }
    }
  }

  Future<void> _loadArtStyles({bool showError = true}) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loadingArtStyles = true);

    try {
      final styles = await ref.read(illustrationApiProvider).listArtStyles();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedArtStyleId =
            _selectedArtStyleId ?? (styles.isNotEmpty ? styles.first.id : null);
      });
    } catch (error) {
      if (!mounted || !showError) {
        return;
      }
      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _loadingArtStyles = false);
      }
    }
  }

  Future<void> _applyTemplatePrefill(String templateId) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _applyingTemplate = true);
    try {
      final prefill = await ref
          .read(storyApiProvider)
          .getStoryTemplatePrefill(token, templateId);
      if (!mounted) {
        return;
      }

      final charactersText = prefill.characters
          .map((item) => (item['name'] ?? '').trim())
          .where((item) => item.isNotEmpty)
          .join(', ');

      setState(() {
        if (_titleController.text.trim().isEmpty && prefill.title.isNotEmpty) {
          _titleController.text = prefill.title;
        }
        if (prefill.theme.trim().isNotEmpty) {
          _themeController.text = prefill.theme.trim();
        }
        if (prefill.scenario.trim().isNotEmpty) {
          _scenarioController.text = prefill.scenario.trim();
        }
        if (prefill.objective.trim().isNotEmpty) {
          _objectiveController.text = prefill.objective.trim();
        }
        if (charactersText.isNotEmpty) {
          _charactersController.text = charactersText;
        }
        if (prefill.virtueId != null &&
            prefill.virtueId!.isNotEmpty &&
            _virtues.any((virtue) => virtue.id == prefill.virtueId)) {
          _selectedVirtueId = prefill.virtueId;
        }
        _suggestionReason = 'Template aplicado: ${prefill.title}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _applyingTemplate = false);
      }
    }
  }

  Future<void> _onTemplateSelected(String? templateId) async {
    setState(() {
      _selectedTemplateId = templateId;
      _suggestionReason = null;
      _recommendationFeedback = null;
    });

    if (templateId == null || templateId.isEmpty) {
      return;
    }
    await _applyTemplatePrefill(templateId);
  }

  List<String> _characterNames() {
    return _charactersController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Map<String, String?>> _characterPayload() {
    return _characterNames()
        .take(8)
        .map((name) => <String, String?>{'name': name})
        .toList();
  }

  QuickStoryDefaults? _buildDefaults({String? selectedChildId}) {
    return buildQuickStoryDefaults(
      children: _children,
      collections: _recentCollections,
      templates: _templates,
      selectedChildId: selectedChildId ?? _selectedChildId,
      suggestedVirtueId: _selectedVirtueId,
    );
  }

  QuickStoryRecommendations? _buildRecommendations() {
    return buildQuickStoryRecommendations(
      children: _children,
      collections: _recentCollections,
      templates: _templates,
      virtues: _virtues,
      selectedChildId: _selectedChildId,
    );
  }

  void _applyRecommendationSelection({
    required QuickStoryRecommendations recommendation,
    bool withFeedback = true,
  }) {
    final suggestedVirtueId = recommendation.virtueSuggestions.isNotEmpty
        ? recommendation.virtueSuggestions.first.id
        : _selectedVirtueId;
    final defaults = _buildDefaults(selectedChildId: recommendation.child.id);

    setState(() {
      _selectedChildId = recommendation.child.id;
      _selectedTemplateId =
          _selectedTemplateId ?? recommendation.sourceTemplateId;
      _selectedVirtueId = suggestedVirtueId ?? defaults?.virtueId;

      if (_themeController.text.trim().isEmpty &&
          recommendation.themeSuggestions.isNotEmpty) {
        _themeController.text = recommendation.themeSuggestions.first;
      }

      if (_titleController.text.trim().isEmpty && defaults != null) {
        _titleController.text = defaults.titleDraft;
      }
      if (_scenarioController.text.trim().isEmpty && defaults != null) {
        _scenarioController.text = defaults.scenario;
      }
      if (_objectiveController.text.trim().isEmpty && defaults != null) {
        _objectiveController.text = defaults.objective;
      }
      if (_charactersController.text.trim().isEmpty && defaults != null) {
        _charactersController.text = defaults.characters
            .map((item) => item['name'] ?? '')
            .where((item) => item.trim().isNotEmpty)
            .join(', ');
      }

      _suggestionReason = recommendation.reason;
      if (withFeedback) {
        _recommendationFeedback =
            'Sugestão aplicada para ${recommendation.child.name}.';
      }
    });
  }

  Future<void> _startWithRecommendation(
    QuickStoryRecommendations recommendation,
  ) async {
    if (_busyAction) {
      return;
    }

    _applyRecommendationSelection(
      recommendation: recommendation,
      withFeedback: false,
    );
    await _createAdventure(completionReason: 'recommendation_applied');
  }

  Future<void> _clearLocalDraft() async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) {
      return;
    }
    try {
      await ref.read(createStoryWizardDraftStoreProvider).clear(userId);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao limpar rascunho local do wizard.',
        error: error,
        stackTrace: stackTrace,
        scope: 'story_creation',
      );
    }
  }

  void _logStepCompleted({required String reason}) {
    final durationMs = DateTime.now().difference(_stepStartedAt).inMilliseconds;

    UxAnalytics.log(
      'story_create_step_completed',
      params: <String, Object?>{
        'step': 1,
        'child_id': _selectedChildId,
        'source': 'create_story_screen',
        'flow': 'wizard',
        'duration_ms': durationMs,
        'reason': reason,
      },
    );
  }

  Future<bool> _createDraftFromStepOne({
    required String completionReason,
  }) async {
    if (_storyId != null && _storyId!.isNotEmpty) {
      final existingId = _storyId!.trim();
      final existingTitle = _titleController.text.trim();
      final normalizedTitleDraft = existingTitle.isEmpty
          ? 'Aventura sem nome'
          : existingTitle;

      final updated = await ref
          .read(storyRoomControllerProvider.notifier)
          .updateSessionSetupById(
            storyId: existingId,
            titleDraft: normalizedTitleDraft,
            theme: _themeController.text.trim(),
            scenario: _scenarioController.text.trim(),
            objective: _objectiveController.text.trim(),
            characters: _characterPayload(),
            virtueId: _selectedVirtueId,
            sourceTemplateId: _selectedTemplateId,
            updateSourceTemplate: true,
            artStyleId: _selectedArtStyleId,
            updateArtStyle: true,
            mode: _mode,
          );

      if (updated == null) {
        final error = ref.read(storyRoomControllerProvider).error;
        if (!mounted) {
          return false;
        }
        context.showMessage(error ?? 'Falha ao atualizar a aventura.');
        return false;
      }

      _applySessionToForm(updated, replaceText: false);
      final normalizedTitle = updated.title.trim().isNotEmpty
          ? updated.title.trim()
          : updated.titleDraft.trim();

      ref
          .read(gameAdventureSessionControllerProvider.notifier)
          .setFromStory(
            storyId: updated.id,
            title: normalizedTitle.isEmpty
                ? 'Aventura sem nome'
                : normalizedTitle,
            childProfileId: updated.childProfileId,
            theme: updated.theme,
            biome: updated.gameSummary?.biome ?? updated.game?.map.biome,
          );
      _logStepCompleted(reason: completionReason);
      _flowCompleted = true;
      await _clearLocalDraft();
      if (!mounted) {
        return false;
      }
      context.go(
        AppRoute.storyGameReadyPath(
          storyId: updated.id,
          title: normalizedTitle.isEmpty
              ? 'Aventura sem nome'
              : normalizedTitle,
        ),
      );
      return true;
    }

    final childId = _selectedChildId;
    if (childId == null || childId.isEmpty) {
      context.showMessage('Selecione uma criança para iniciar.');
      return false;
    }

    final defaults = _buildDefaults();
    if (defaults == null) {
      context.showMessage('Não foi possível preparar os dados da história.');
      return false;
    }

    if (_titleController.text.trim().isEmpty) {
      _titleController.text = defaults.titleDraft;
    }
    if (_themeController.text.trim().isEmpty) {
      _themeController.text = defaults.theme;
    }
    if (_scenarioController.text.trim().isEmpty) {
      _scenarioController.text = defaults.scenario;
    }
    if (_objectiveController.text.trim().isEmpty) {
      _objectiveController.text = defaults.objective;
    }
    if (_charactersController.text.trim().isEmpty) {
      _charactersController.text = defaults.characters
          .map((item) => item['name'] ?? '')
          .where((item) => item.trim().isNotEmpty)
          .join(', ');
    }

    _selectedTemplateId = _selectedTemplateId ?? defaults.sourceTemplateId;
    _selectedVirtueId = _selectedVirtueId ?? defaults.virtueId;

    final created = await ref
        .read(storyRoomControllerProvider.notifier)
        .createSession(
          childProfileId: childId,
          titleDraft: _titleController.text.trim(),
          theme: _themeController.text.trim(),
          scenario: _scenarioController.text.trim(),
          characters: _characterPayload(),
          objective: _objectiveController.text.trim(),
          startMode: _mode,
          virtueId: _selectedVirtueId,
          sourceTemplateId: _selectedTemplateId,
          artStyleId: _selectedArtStyleId,
        );

    if (created == null) {
      final error = ref.read(storyRoomControllerProvider).error;
      if (!mounted) {
        return false;
      }
      context.showMessage(error ?? 'Falha ao criar rascunho.');
      return false;
    }

    _applySessionToForm(created, replaceText: false);
    final createdTitle = created.title.trim().isNotEmpty
        ? created.title.trim()
        : created.titleDraft.trim();
    ref
        .read(gameAdventureSessionControllerProvider.notifier)
        .setFromStory(
          storyId: created.id,
          title: createdTitle.isEmpty ? 'Aventura sem nome' : createdTitle,
          childProfileId: created.childProfileId,
          theme: created.theme,
          biome: created.gameSummary?.biome ?? created.game?.map.biome,
        );

    _logStepCompleted(reason: completionReason);
    _flowCompleted = true;
    await _clearLocalDraft();
    if (!mounted) {
      return false;
    }
    context.go(
      AppRoute.storyGameReadyPath(
        storyId: created.id,
        title: createdTitle.isEmpty ? 'Aventura sem nome' : createdTitle,
      ),
    );
    return true;
  }

  Future<void> _createAdventure({required String completionReason}) async {
    if (_busyAction) {
      return;
    }

    setState(() => _busyAction = true);

    await _createDraftFromStepOne(completionReason: completionReason);

    if (!mounted) {
      return;
    }

    setState(() => _busyAction = false);
  }

  Widget _buildIntroCard(BuildContext context) {
    final colors = context.viscondeColors;

    return ViscondeGlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_stories, color: colors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Criar nova aventura',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Escolha criança e personalização básica. O restante é automático.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCompactCard(BuildContext context) {
    final recommendation = _buildRecommendations();
    if (recommendation == null || _children.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasLoadingDependencies =
        _loadingVirtues ||
        _loadingTemplates ||
        _loadingCollections ||
        _loadingArtStyles ||
        _applyingTemplate;

    final topTheme = recommendation.themeSuggestions.isEmpty
        ? 'Aventura'
        : recommendation.themeSuggestions.first;
    final topVirtue = recommendation.virtueSuggestions.isEmpty
        ? (_selectedVirtueId == null
              ? 'Sem virtude'
              : (_virtues
                        .where((v) => v.id == _selectedVirtueId)
                        .firstOrNull
                        ?.name ??
                    'Sem virtude'))
        : recommendation.virtueSuggestions.first.name;

    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Para ${recommendation.child.name}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            recommendation.reason,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.palette_outlined, size: 16),
                label: Text('Tema: $topTheme'),
              ),
              Chip(
                avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                label: Text('Virtude: $topVirtue'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('wizard_recommendation_quick_start_button'),
            onPressed:
                (_storyId != null || _busyAction || hasLoadingDependencies)
                ? null
                : () => _startWithRecommendation(recommendation),
            icon: Icon(_busyAction ? Icons.hourglass_top : Icons.auto_awesome),
            label: Text(
              _busyAction ? 'Criando...' : 'Aplicar sugestão e criar',
            ),
          ),
          if (_recommendationFeedback != null &&
              _recommendationFeedback!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _recommendationFeedback!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationCard(BuildContext context) {
    final selectedChildValue =
        _children.any((item) => item.id == _selectedChildId)
        ? _selectedChildId
        : null;
    final selectedVirtueValue =
        _virtues.any((item) => item.id == _selectedVirtueId)
        ? _selectedVirtueId
        : null;
    final selectedTemplateValue =
        _templates.any((item) => item.id == _selectedTemplateId)
        ? _selectedTemplateId
        : null;

    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ViscondeSectionTitle(
            title: 'Personalização',
            subtitle: 'Ajuste o essencial antes de criar.',
          ),
          if (_loadingVirtues ||
              _loadingTemplates ||
              _loadingCollections ||
              _loadingArtStyles ||
              _applyingTemplate)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 12),
          if (_children.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Cadastre ao menos uma criança em Perfil > Crianças antes de iniciar.',
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: selectedChildValue,
            items: _children
                .map(
                  (child) => DropdownMenuItem(
                    value: child.id,
                    child: Text(child.name),
                  ),
                )
                .toList(),
            onChanged: _busyAction
                ? null
                : (value) {
                    setState(() {
                      _selectedChildId = value;
                      _recommendationFeedback = null;
                    });
                  },
            decoration: const InputDecoration(labelText: 'Criança'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<StoryMode>(
            segments: const [
              ButtonSegment<StoryMode>(
                value: StoryMode.parentNarrator,
                label: Text('Pai narrador'),
              ),
              ButtonSegment<StoryMode>(
                value: StoryMode.childChooser,
                label: Text('Criança escolhe'),
              ),
            ],
            selected: <StoryMode>{_mode},
            onSelectionChanged: _busyAction
                ? null
                : (values) {
                    setState(() => _mode = values.first);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _themeController,
            enabled: !_busyAction,
            decoration: const InputDecoration(labelText: 'Tema da aventura'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedVirtueValue,
            items: _virtues
                .map(
                  (virtue) => DropdownMenuItem(
                    value: virtue.id,
                    child: Text(virtue.name),
                  ),
                )
                .toList(),
            onChanged: _virtues.isEmpty || _busyAction
                ? null
                : (value) {
                    setState(() => _selectedVirtueId = value);
                  },
            decoration: const InputDecoration(labelText: 'Virtude principal'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: selectedTemplateValue,
            decoration: const InputDecoration(
              labelText: 'Template publicado (opcional)',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sem template'),
              ),
              ..._templates.map(
                (template) => DropdownMenuItem<String?>(
                  value: template.id,
                  child: Text(template.title),
                ),
              ),
            ],
            onChanged: _loadingTemplates || _applyingTemplate || _busyAction
                ? null
                : _onTemplateSelected,
          ),
          if (_suggestionReason != null && _suggestionReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _suggestionReason!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loadingDependencies =
        _loadingVirtues ||
        _loadingTemplates ||
        _loadingCollections ||
        _loadingArtStyles ||
        _applyingTemplate;

    if (_bootstrapLoading || _loadingChildren) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Aventura')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _buildIntroCard(context),
            const SizedBox(height: 12),
            _buildRecommendationsCompactCard(context),
            const SizedBox(height: 12),
            _buildPersonalizationCard(context),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            key: const Key('wizard_save_continue_button'),
            onPressed: (_busyAction || loadingDependencies)
                ? null
                : () => _createAdventure(completionReason: 'manual_create'),
            icon: Icon(_busyAction ? Icons.hourglass_top : Icons.explore),
            label: Text(_busyAction ? 'Criando...' : 'Criar aventura'),
          ),
        ),
      ),
    );
  }
}

extension on Iterable<VirtueModel> {
  VirtueModel? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
