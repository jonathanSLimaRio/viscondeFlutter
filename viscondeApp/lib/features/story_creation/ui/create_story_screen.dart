import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/logging/app_logger.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/app_feedback.dart';
import '../../../shared/ui/post_publish_celebration_dialog.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';
import '../../gamification/inventory_models.dart';
import '../../story_creation/create_story_wizard_draft_store.dart';
import '../../story_creation/quick_story_defaults.dart';
import '../../story_room/models/illustration_models.dart';
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
  List<ArtStyleModel> _artStyles = const [];

  String? _storyId;
  String? _selectedChildId;
  String? _selectedVirtueId;
  String? _selectedTemplateId;
  String? _selectedArtStyleId;
  String? _suggestionReason;

  StoryMode _mode = StoryMode.parentNarrator;

  bool _loadingChildren = false;
  bool _loadingVirtues = false;
  bool _loadingTemplates = false;
  bool _loadingArtStyles = false;
  bool _loadingCollections = false;
  bool _applyingTemplate = false;
  bool _suggestingVirtue = false;
  bool _busyAction = false;
  bool _bootstrapLoading = true;
  bool _flowCompleted = false;
  bool _continuedLater = false;
  bool _step3Logged = false;
  bool _stepOneUsedRecommendation = false;

  String? _recommendationFeedback;

  int _currentStep = 0;
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
    if (!_flowCompleted && !_continuedLater) {
      final durationMs = DateTime.now()
          .difference(_stepStartedAt)
          .inMilliseconds;
      UxAnalytics.log(
        'story_create_abandoned',
        params: <String, Object?>{
          'step': _currentStep + 1,
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
    final loadedDraft = draft;

    StorySessionModel? session;
    if (loadedDraft.storyId != null && loadedDraft.storyId!.isNotEmpty) {
      try {
        session = await ref
            .read(storyApiProvider)
            .getStorySession(token, loadedDraft.storyId!);
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
      _storyId = loadedDraft.storyId;
      _currentStep = loadedDraft.currentStep;
      _selectedChildId = loadedDraft.selectedChildId;
      _selectedVirtueId = loadedDraft.selectedVirtueId;
      _selectedTemplateId = loadedDraft.selectedTemplateId;
      _selectedArtStyleId = loadedDraft.selectedArtStyleId;
      _mode = loadedDraft.mode;
      _titleController.text = loadedDraft.titleDraft;
      _themeController.text = loadedDraft.theme;
      _scenarioController.text = loadedDraft.scenario;
      _objectiveController.text = loadedDraft.objective;
      _charactersController.text = loadedDraft.characters;

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
        _artStyles = styles;
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
        _suggestionReason = 'Template aplicado: ${prefill.title}.';
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
    });

    if (templateId == null || templateId.isEmpty) {
      return;
    }
    await _applyTemplatePrefill(templateId);
  }

  Future<void> _suggestVirtueAutomatically() async {
    final token = _accessToken();
    final childId = _selectedChildId;

    if (token == null || childId == null) {
      return;
    }

    setState(() => _suggestingVirtue = true);

    try {
      final suggestion = await ref
          .read(storyApiProvider)
          .suggestVirtue(token, childProfileId: childId);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedVirtueId = suggestion.virtue.id;
        _suggestionReason = suggestion.reason;
      });

      context.showMessage('Sugestão: ${suggestion.virtue.name}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _suggestingVirtue = false);
      }
    }
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_selectedChildId == null) {
          context.showMessage('Selecione uma criança para continuar.');
          return false;
        }
        return true;
      case 1:
        if (_virtues.isNotEmpty &&
            (_selectedVirtueId == null || _selectedVirtueId!.isEmpty)) {
          context.showMessage('Selecione uma virtude para continuar.');
          return false;
        }
        if (_artStyles.isNotEmpty &&
            (_selectedArtStyleId == null || _selectedArtStyleId!.isEmpty)) {
          context.showMessage(
            'Selecione um estilo de ilustração para continuar.',
          );
          return false;
        }
        return true;
      case 2:
        final title = _titleController.text.trim();
        final theme = _themeController.text.trim();
        final scenario = _scenarioController.text.trim();
        final objective = _objectiveController.text.trim();

        if (title.isEmpty ||
            theme.isEmpty ||
            scenario.isEmpty ||
            objective.isEmpty) {
          context.showMessage('Preencha título, tema, cenário e objetivo.');
          return false;
        }

        final characters = _characterNames();
        if (characters.isEmpty) {
          context.showMessage(
            'Informe ao menos um personagem (separados por vírgula).',
          );
          return false;
        }
        return true;
      default:
        return true;
    }
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
        .map((name) => <String, String?>{'name': name, 'role': null})
        .toList();
  }

  QuickStoryDefaults? _buildDefaults() {
    return buildQuickStoryDefaults(
      children: _children,
      collections: _recentCollections,
      templates: _templates,
      selectedChildId: _selectedChildId,
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
    String? theme,
    String? virtueId,
    bool withFeedback = true,
  }) {
    final selectedTheme = (theme ?? '').trim();
    final effectiveVirtueId = (virtueId ?? '').trim().isNotEmpty
        ? virtueId!.trim()
        : recommendation.virtueSuggestions.isNotEmpty
        ? recommendation.virtueSuggestions.first.id
        : _selectedVirtueId;
    final defaults = buildQuickStoryDefaults(
      children: _children,
      collections: _recentCollections,
      templates: _templates,
      selectedChildId: recommendation.child.id,
      suggestedVirtueId: effectiveVirtueId,
    );

    setState(() {
      _selectedChildId = recommendation.child.id;
      _selectedTemplateId =
          _selectedTemplateId ?? recommendation.sourceTemplateId;
      _selectedVirtueId = effectiveVirtueId ?? defaults?.virtueId;

      if (selectedTheme.isNotEmpty) {
        _themeController.text = selectedTheme;
      } else if (_themeController.text.trim().isEmpty &&
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

      _stepOneUsedRecommendation = true;
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
    await _goNextStep();
  }

  Widget _buildRecommendationsBlock(BuildContext context) {
    final recommendation = _buildRecommendations();
    if (recommendation == null || _children.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedTheme = _themeController.text.trim();
    final hasLoadingDependencies =
        _loadingVirtues || _loadingTemplates || _loadingCollections;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
        gradient: context.viscondeGradients.hero,
      ),
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
          if (recommendation.fallbackUsed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Quando houver mais histórico, as sugestões ficam ainda mais personalizadas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Temas recomendados',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recommendation.themeSuggestions
                .map(
                  (theme) => ViscondePillChip(
                    label: theme,
                    selected:
                        selectedTheme.isNotEmpty &&
                        selectedTheme.toLowerCase() == theme.toLowerCase(),
                    onTap: _busyAction
                        ? null
                        : () {
                            _applyRecommendationSelection(
                              recommendation: recommendation,
                              theme: theme,
                            );
                          },
                  ),
                )
                .toList(growable: false),
          ),
          if (recommendation.virtueSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Virtudes recomendadas',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recommendation.virtueSuggestions
                  .map(
                    (virtue) => ViscondePillChip(
                      label: virtue.name,
                      selected: _selectedVirtueId == virtue.id,
                      onTap: _busyAction
                          ? null
                          : () {
                              _applyRecommendationSelection(
                                recommendation: recommendation,
                                virtueId: virtue.id,
                              );
                            },
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('wizard_recommendation_quick_start_button'),
            onPressed:
                (_storyId != null || _busyAction || hasLoadingDependencies)
                ? null
                : () => _startWithRecommendation(recommendation),
            icon: const Icon(Icons.flash_on),
            label: const Text('Criar com sugestão rápida'),
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

  Future<void> _saveLocalDraft({required int currentStep}) async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) {
      return;
    }

    final draft = CreateStoryWizardDraft(
      userId: userId,
      storyId: _storyId,
      currentStep: currentStep,
      selectedChildId: _selectedChildId,
      selectedVirtueId: _selectedVirtueId,
      selectedTemplateId: _selectedTemplateId,
      selectedArtStyleId: _selectedArtStyleId,
      mode: _mode,
      titleDraft: _titleController.text.trim(),
      theme: _themeController.text.trim(),
      scenario: _scenarioController.text.trim(),
      objective: _objectiveController.text.trim(),
      characters: _charactersController.text.trim(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(createStoryWizardDraftStoreProvider).save(draft);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao salvar rascunho local do wizard.',
        error: error,
        stackTrace: stackTrace,
        scope: 'story_creation',
      );
    }
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

  void _logStepCompleted(int step, {String? reason}) {
    final durationMs = DateTime.now().difference(_stepStartedAt).inMilliseconds;

    UxAnalytics.log(
      'story_create_step_completed',
      params: <String, Object?>{
        'step': step,
        'child_id': _selectedChildId,
        'source': 'create_story_screen',
        'flow': 'wizard',
        'duration_ms': durationMs,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  void _enterStep(int step) {
    setState(() {
      _currentStep = step;
      _stepStartedAt = DateTime.now();
    });
  }

  Future<bool> _createDraftFromStepOne() async {
    if (_storyId != null && _storyId!.isNotEmpty) {
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
    await _saveLocalDraft(currentStep: 1);
    return true;
  }

  Future<bool> _autosaveSetup({required int currentStepToPersist}) async {
    if (!_validateStep(2)) {
      return false;
    }

    var storyId = _storyId;
    if (storyId == null || storyId.isEmpty) {
      final created = await _createDraftFromStepOne();
      if (!created) {
        return false;
      }
      storyId = _storyId;
    }

    if (storyId == null || storyId.isEmpty) {
      if (!mounted) {
        return false;
      }
      context.showMessage(
        'Não foi possível identificar o rascunho para salvar.',
      );
      return false;
    }

    final updated = await ref
        .read(storyRoomControllerProvider.notifier)
        .updateSessionSetup(
          titleDraft: _titleController.text.trim(),
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
      context.showMessage(error ?? 'Não foi possível salvar o rascunho.');
      return false;
    }

    _applySessionToForm(updated);
    await _saveLocalDraft(currentStep: currentStepToPersist);
    return true;
  }

  Future<void> _goNextStep() async {
    if (_busyAction || _currentStep >= 2) {
      return;
    }

    if (!_validateStep(_currentStep)) {
      return;
    }

    setState(() => _busyAction = true);

    final completionReason = _currentStep == 0 && _stepOneUsedRecommendation
        ? 'recommendation_applied'
        : null;
    var proceed = false;
    if (_currentStep == 0) {
      proceed = await _createDraftFromStepOne();
      if (proceed) {
        await _saveLocalDraft(currentStep: 1);
      }
    } else if (_currentStep == 1) {
      proceed = await _autosaveSetup(currentStepToPersist: 2);
    }

    if (!mounted) {
      return;
    }

    setState(() => _busyAction = false);

    if (!proceed) {
      return;
    }

    _logStepCompleted(_currentStep + 1, reason: completionReason);
    if (_currentStep == 0) {
      _stepOneUsedRecommendation = false;
    }
    _enterStep(_currentStep + 1);
  }

  void _goPreviousStep() {
    if (_busyAction || _currentStep == 0) {
      return;
    }
    _enterStep(_currentStep - 1);
  }

  void _logStep3Once({required String reason}) {
    if (_step3Logged) {
      return;
    }
    _step3Logged = true;
    _logStepCompleted(3, reason: reason);
  }

  bool _isOnCreateRoute() {
    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    return currentPath == AppRoute.storyCreate;
  }

  Future<void> _ensurePostPublishNavigation() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    if (_isOnCreateRoute()) {
      context.go(AppRoute.homePath(tab: HomeTab.stories));
    }
  }

  Future<void> _continueLater() async {
    if (_busyAction) {
      return;
    }

    setState(() => _busyAction = true);
    final saved = await _autosaveSetup(currentStepToPersist: 2);
    if (!mounted) {
      return;
    }

    setState(() => _busyAction = false);

    if (!saved) {
      return;
    }

    _logStep3Once(reason: 'continue_later');
    _continuedLater = true;
    context.showMessage('Rascunho salvo. Você pode continuar depois.');
    context.go(AppRoute.home);
  }

  Future<void> _openStoryRoom() async {
    if (_busyAction) {
      return;
    }

    setState(() => _busyAction = true);
    final saved = await _autosaveSetup(currentStepToPersist: 2);
    if (!mounted) {
      return;
    }

    setState(() => _busyAction = false);

    if (!saved || _storyId == null) {
      return;
    }

    _logStep3Once(reason: 'open_story_room');
    _flowCompleted = true;
    await _clearLocalDraft();
    if (!mounted) {
      return;
    }
    context.go(AppRoute.storyRoom(_storyId!));
  }

  Future<void> _publishNow() async {
    if (_busyAction) {
      return;
    }

    setState(() => _busyAction = true);

    final saved = await _autosaveSetup(currentStepToPersist: 2);
    if (!saved || _storyId == null) {
      if (mounted) {
        setState(() => _busyAction = false);
      }
      return;
    }

    try {
      final result = await ref
          .read(storyRoomControllerProvider.notifier)
          .finalize(titleFinal: _titleController.text.trim());

      if (!mounted) {
        return;
      }

      if (result == null) {
        final error = ref.read(storyRoomControllerProvider).error;
        context.showMessage(error ?? 'Não foi possível publicar agora.');
        setState(() => _busyAction = false);
        return;
      }

      final autoCompletedSteps = result.publishMeta?.autoCompletedSteps ?? 0;
      if (autoCompletedSteps > 0) {
        context.showMessage(
          'Capítulo publicado. $autoCompletedSteps etapas foram completadas automaticamente.',
        );
      }

      _logStep3Once(reason: 'publish_now');
      UxAnalytics.log(
        'story_published',
        params: <String, Object?>{
          'story_id': result.story.id,
          'steps': result.story.steps.length,
          'source': 'create_story_screen',
          'flow': 'wizard',
          'auto_completed_steps': autoCompletedSteps,
        },
      );

      await _clearLocalDraft();
      _flowCompleted = true;

      if (!mounted) {
        return;
      }

      ChildInventoryModel? reward;
      try {
        final token = _accessToken();
        if (token != null) {
          reward = await ref
              .read(inventoryApiProvider)
              .rewardRandomItem(result.story.id, token);
        }
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Falha ao buscar recompensa pós-publicação no wizard.',
          error: error,
          stackTrace: stackTrace,
          scope: 'story_creation',
        );
      }

      if (!mounted) {
        return;
      }

      var action = PostPublishAction.backToVault;
      try {
        action = await showPostPublishCelebrationDialog(
          context,
          source: 'create_story_screen',
          flow: 'wizard',
          storyId: result.story.id,
          gamification: result.gamification,
          reward: reward,
        );
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Falha ao abrir pós-publicação no wizard. Aplicando navegação de fallback.',
          error: error,
          stackTrace: stackTrace,
          scope: 'story_creation',
        );
        action = PostPublishAction.backToVault;
      }

      if (!mounted) {
        return;
      }

      await _handlePostPublishAction(action, result.story.id);
      await _ensurePostPublishNavigation();
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = false);
      }
    }
  }

  Future<void> _handlePostPublishAction(
    PostPublishAction action,
    String storyId,
  ) async {
    switch (action) {
      case PostPublishAction.continueSaga:
        final token = _accessToken();
        if (token == null) {
          if (mounted) {
            context.showMessage('Sua sessão expirou. Faça login novamente.');
            context.go(AppRoute.homePath(tab: HomeTab.stories));
          }
          return;
        }
        try {
          final session = await ref
              .read(storyApiProvider)
              .continueStory(token, storyId);
          if (!mounted) {
            return;
          }
          context.go(AppRoute.storyRoom(session.id));
        } catch (error) {
          if (!mounted) {
            return;
          }
          context.showError(error);
          context.go(AppRoute.homePath(tab: HomeTab.stories));
        }
        return;
      case PostPublishAction.goGame:
        if (mounted) {
          context.go(AppRoute.homePath(tab: HomeTab.game));
        }
        return;
      case PostPublishAction.backToVault:
        if (mounted) {
          context.go(AppRoute.homePath(tab: HomeTab.stories));
        }
        return;
    }
  }

  Widget _buildStepThreeActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('wizard_publish_now_button'),
          onPressed: _busyAction ? null : _publishNow,
          icon: const Icon(Icons.publish),
          label: Text(_busyAction ? 'Processando...' : 'Publicar agora'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('wizard_open_story_room_button'),
          onPressed: _busyAction ? null : _openStoryRoom,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Ir para Sala de História'),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          key: const Key('wizard_continue_later_button'),
          onPressed: _busyAction ? null : _continueLater,
          icon: const Icon(Icons.pause_circle_outline),
          label: const Text('Continuar depois'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / 3;

    if (_bootstrapLoading || _loadingChildren) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Sala de História')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ViscondeHeroBanner(
            title: 'Criando com o Papai!',
            subtitle: 'Fluxo guiado para rascunho, revisão e publicação.',
            assetPath: ViscondeArtRegistry.resolve(
              ViscondeArtKey.heroUnderwater,
            ),
            showMascot: true,
            mascotPose: ViscondeMascotPose.observingSpyglass,
          ),
          const SizedBox(height: 12),
          ViscondeGlassCard(
            child: Column(
              children: [
                const ViscondeSectionTitle(
                  title: 'Configuração da História',
                  subtitle: 'Wizard em 3 passos com autosave por etapa.',
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  'Passo ${_currentStep + 1} de 3',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Stepper(
                  currentStep: _currentStep,
                  margin: EdgeInsets.zero,
                  controlsBuilder: (context, details) {
                    if (!details.isActive) {
                      return const SizedBox.shrink();
                    }

                    if (_currentStep == 2) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busyAction ? null : _goPreviousStep,
                                child: const Text('Voltar'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('wizard_save_continue_button'),
                              onPressed: _busyAction ? null : _goNextStep,
                              icon: Icon(
                                _busyAction
                                    ? Icons.hourglass_top
                                    : Icons.arrow_forward,
                              ),
                              label: Text(
                                _busyAction
                                    ? 'Salvando...'
                                    : 'Salvar e continuar',
                              ),
                            ),
                          ),
                          if (_currentStep > 0) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('wizard_back_button'),
                                onPressed: _busyAction ? null : _goPreviousStep,
                                child: const Text('Voltar'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  onStepTapped: (value) {
                    if (value <= _currentStep && !_busyAction) {
                      _enterStep(value);
                    }
                  },
                  steps: [
                    Step(
                      title: const Text('Criança e modo'),
                      subtitle: const Text('Quem participa da aventura'),
                      isActive: _currentStep >= 0,
                      content: Column(
                        children: [
                          if (_children.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Cadastre ao menos uma criança na aba Crianças antes de iniciar.',
                              ),
                            ),
                          _buildRecommendationsBlock(context),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedChildId,
                            items: _children
                                .map(
                                  (child) => DropdownMenuItem(
                                    value: child.id,
                                    child: Text(child.name),
                                  ),
                                )
                                .toList(),
                            onChanged: _storyId != null
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedChildId = value;
                                      _stepOneUsedRecommendation = false;
                                      _recommendationFeedback = null;
                                    });
                                  },
                            decoration: InputDecoration(
                              labelText: 'Criança',
                              helperText: _storyId == null
                                  ? null
                                  : 'A criança fica bloqueada após criar o rascunho.',
                            ),
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
                            onSelectionChanged: (values) {
                              setState(() => _mode = values.first);
                            },
                          ),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('Template, virtude e estilo'),
                      subtitle: const Text('Personalização principal'),
                      isActive: _currentStep >= 1,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadingVirtues ||
                              _loadingArtStyles ||
                              _loadingTemplates ||
                              _applyingTemplate)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(),
                            ),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedVirtueId,
                            items: _virtues
                                .map(
                                  (virtue) => DropdownMenuItem(
                                    value: virtue.id,
                                    child: Text(virtue.name),
                                  ),
                                )
                                .toList(),
                            onChanged: _virtues.isEmpty
                                ? null
                                : (value) {
                                    setState(() => _selectedVirtueId = value);
                                  },
                            decoration: const InputDecoration(
                              labelText: 'Virtude principal',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed:
                                (_suggestingVirtue || _selectedChildId == null)
                                ? null
                                : _suggestVirtueAutomatically,
                            icon: const Icon(Icons.auto_awesome),
                            label: Text(
                              _suggestingVirtue
                                  ? 'Sugerindo...'
                                  : 'Sugerir automaticamente por idade',
                            ),
                          ),
                          if (_suggestionReason != null &&
                              _suggestionReason!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _suggestionReason!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedArtStyleId,
                            decoration: const InputDecoration(
                              labelText: 'Estilo de ilustração',
                            ),
                            items: _artStyles
                                .map(
                                  (style) => DropdownMenuItem(
                                    value: style.id,
                                    child: Text(style.name),
                                  ),
                                )
                                .toList(),
                            onChanged: _artStyles.isEmpty
                                ? null
                                : (value) {
                                    setState(() => _selectedArtStyleId = value);
                                  },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedTemplateId,
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
                            onChanged: _loadingTemplates || _applyingTemplate
                                ? null
                                : _onTemplateSelected,
                          ),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('Detalhes, revisão e publicar'),
                      subtitle: const Text(
                        'Revise e finalize em poucos toques',
                      ),
                      isActive: _currentStep >= 2,
                      content: Column(
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Título provisório',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _themeController,
                            decoration: const InputDecoration(
                              labelText: 'Tema',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _scenarioController,
                            decoration: const InputDecoration(
                              labelText: 'Cenário',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _objectiveController,
                            decoration: const InputDecoration(
                              labelText: 'Objetivo da aventura',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _charactersController,
                            decoration: const InputDecoration(
                              labelText: 'Personagens (separe por vírgula)',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStepThreeActions(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
