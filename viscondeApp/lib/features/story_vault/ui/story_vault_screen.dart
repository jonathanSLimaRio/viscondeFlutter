import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_route.dart';
import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/logging/app_logger.dart';
import '../../../shared/ui/app_feedback.dart';
import '../../../shared/ui/ui_state_copy.dart';
import '../../../shared/providers.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';
import '../../story_creation/create_story_wizard_draft_store.dart';
import '../../story_creation/quick_story_defaults.dart';
import '../../story_room/models/story_models.dart';
import '../../story_room/story_room_controller.dart';
import '../story_vault_adventure_resolver.dart';
import '../story_pdf_exporter.dart';

class StoryVaultScreen extends ConsumerStatefulWidget {
  const StoryVaultScreen({super.key});

  @override
  ConsumerState<StoryVaultScreen> createState() => _StoryVaultScreenState();
}

class _StoryVaultScreenState extends ConsumerState<StoryVaultScreen> {
  List<StoryVaultCollectionItem> _collections = const [];
  List<ChildProfile> _children = const [];
  List<VirtueModel> _virtues = const [];

  bool _loadingInitial = true;
  bool _loadingCollections = false;
  bool _loadingFilters = false;
  bool _favoriteOnly = false;
  bool _quickCreating = false;
  bool _isFilterExpanded = false;
  String? _busyCollectionId;
  CreateStoryWizardDraft? _resumeDraft;
  String? _blockingError;
  String? _inlineError;
  String? _lastTrackedState;

  String? _selectedChildId;
  String? _selectedVirtueId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _themeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  Future<void> _bootstrap() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingInitial = true;
      _blockingError = null;
      _inlineError = null;
    });
    _trackVaultState('loading');

    await _loadFiltersData(isInitial: true);
    await _loadCollections(isInitial: true);
    await _loadResumeDraft();

    if (!mounted) {
      return;
    }

    setState(() => _loadingInitial = false);
    _trackVaultState(_computeVaultState());
  }

  Future<void> _loadResumeDraft() async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) {
      return;
    }

    CreateStoryWizardDraft? draft;
    try {
      draft = await ref.read(createStoryWizardDraftStoreProvider).read(userId);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao ler rascunho local para retomada no Baú.',
        error: error,
        stackTrace: stackTrace,
        scope: 'story_vault',
      );
      draft = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _resumeDraft = draft;
    });
  }

  Future<void> _discardResumeDraft() async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) {
      return;
    }
    try {
      await ref.read(createStoryWizardDraftStoreProvider).clear(userId);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao descartar rascunho local no Baú.',
        error: error,
        stackTrace: stackTrace,
        scope: 'story_vault',
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _resumeDraft = null;
    });
    _showSnackMessage('Rascunho local descartado.');
  }

  Future<void> _openCreateWithResume({required bool resume}) async {
    await context.push(AppRoute.storyCreatePath(resumeDraft: resume));
    if (!mounted) {
      return;
    }
    await _loadResumeDraft();
    await _loadCollections();
  }

  Future<void> _loadFiltersData({bool isInitial = false}) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loadingFilters = true);
    try {
      final result = await Future.wait([
        ref.read(childrenApiProvider).listChildren(token),
        ref.read(storyApiProvider).listVirtues(token),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _children = result[0] as List<ChildProfile>;
        _virtues = result[1] as List<VirtueModel>;
        _inlineError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = parseDioError(error);
      setState(() {
        if (isInitial && _collections.isEmpty) {
          _blockingError = message;
        } else {
          _inlineError = message;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFilters = false);
      }
    }
  }

  Future<void> _loadCollections({bool isInitial = false}) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loadingCollections = true);
    try {
      final collections = await ref
          .read(storyApiProvider)
          .listStoryVaultCollections(
            token,
            childProfileId: _selectedChildId,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            theme: _themeController.text.trim().isEmpty
                ? null
                : _themeController.text.trim(),
            virtueId: _selectedVirtueId,
            favoriteOnly: _favoriteOnly,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _collections = collections;
        _blockingError = null;
        _inlineError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = parseDioError(error);
      setState(() {
        if (isInitial && _collections.isEmpty) {
          _blockingError = message;
        } else {
          _inlineError = message;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loadingCollections = false);
        _trackVaultState(_computeVaultState());
      }
    }
  }

  Future<void> _toggleFavorite(StoryVaultCollectionItem item) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    try {
      await ref
          .read(storyApiProvider)
          .setStoryVaultFavorite(token, item.id, isFavorite: !item.isFavorite);
      await _loadCollections();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    }
  }

  Future<void> _generateMonthlyBook() async {
    final token = _accessToken();
    if (token == null || _selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma criança nos filtros primeiro.'),
        ),
      );
      return;
    }

    setState(() => _loadingCollections = true);
    try {
      final now = DateTime.now();
      final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final book = await ref
          .read(bookApiProvider)
          .createMonthlyBook(_selectedChildId!, monthStr, token);

      await StoryPdfExporter.exportBookProject(book);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma história concluída neste mês para gerar o livro.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingCollections = false);
    }
  }

  Future<void> _pickFromDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 1, 1),
      initialDate: _dateFrom ?? DateTime.now(),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() => _dateFrom = selected);
    await _loadCollections();
  }

  Future<void> _pickToDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 1, 1),
      initialDate: _dateTo ?? DateTime.now(),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() => _dateTo = selected);
    await _loadCollections();
  }

  bool get _hasActiveFilters {
    return _selectedChildId != null ||
        _selectedVirtueId != null ||
        _dateFrom != null ||
        _dateTo != null ||
        _favoriteOnly ||
        _themeController.text.trim().isNotEmpty;
  }

  int get _activeFiltersCount {
    var count = 0;
    if (_selectedChildId != null) {
      count += 1;
    }
    if (_selectedVirtueId != null) {
      count += 1;
    }
    if (_dateFrom != null || _dateTo != null) {
      count += 1;
    }
    if (_favoriteOnly) {
      count += 1;
    }
    if (_themeController.text.trim().isNotEmpty) {
      count += 1;
    }
    return count;
  }

  String? _childLabel(String childId) {
    for (final child in _children) {
      if (child.id == childId) {
        return child.name;
      }
    }
    return null;
  }

  String? _virtueLabel(String virtueId) {
    for (final virtue in _virtues) {
      if (virtue.id == virtueId) {
        return virtue.name;
      }
    }
    return null;
  }

  List<String> _activeFilterLabels(DateFormat dateFormat) {
    final labels = <String>[];
    final theme = _themeController.text.trim();
    if (theme.isNotEmpty) {
      labels.add('Tema: $theme');
    }
    if (_selectedChildId case final childId?) {
      labels.add('Criança: ${_childLabel(childId) ?? 'Selecionada'}');
    }
    if (_selectedVirtueId case final virtueId?) {
      labels.add('Virtude: ${_virtueLabel(virtueId) ?? 'Selecionada'}');
    }
    if (_dateFrom != null || _dateTo != null) {
      final from = _dateFrom == null ? '...' : dateFormat.format(_dateFrom!);
      final to = _dateTo == null ? '...' : dateFormat.format(_dateTo!);
      labels.add('Período: $from - $to');
    }
    if (_favoriteOnly) {
      labels.add('Somente favoritas');
    }
    return labels;
  }

  String _computeVaultState() {
    if (_loadingInitial) {
      return 'loading';
    }

    if (_blockingError != null && _collections.isEmpty) {
      return 'error_blocking';
    }

    if (_collections.isEmpty) {
      return _hasActiveFilters ? 'empty_filtered' : 'empty';
    }

    return 'content';
  }

  void _trackVaultState(String state) {
    if (_lastTrackedState == state) {
      return;
    }
    _lastTrackedState = state;
    UxAnalytics.log(
      'vault_state_shown',
      params: <String, Object?>{
        'screen': 'vault',
        'state': state,
        'filtered': _hasActiveFilters,
        'source': 'story_vault_screen',
      },
    );
  }

  Future<void> _retryVaultLoad() async {
    UxAnalytics.log(
      'vault_retry_tapped',
      params: const <String, Object?>{
        'screen': 'vault',
        'source': 'story_vault_screen',
      },
    );
    if (_collections.isEmpty) {
      await _bootstrap();
      return;
    }
    await _loadCollections();
  }

  Future<void> _clearFiltersAndReload() async {
    setState(() {
      _selectedChildId = null;
      _selectedVirtueId = null;
      _dateFrom = null;
      _dateTo = null;
      _favoriteOnly = false;
      _themeController.clear();
    });
    await _loadCollections();
  }

  void _showSnackMessage(String message) {
    context.showMessage(message);
  }

  bool _isCollectionBusy(String collectionId) {
    return _busyCollectionId == collectionId;
  }

  StoryVaultCollectionItem? _collectionById(String collectionId) {
    for (final item in _collections) {
      if (item.id == collectionId) {
        return item;
      }
    }
    return null;
  }

  StoryVaultEpisodeDetail? _latestEpisodeFromDetail(
    StoryVaultCollectionDetail detail,
  ) {
    if (detail.episodes.isEmpty) {
      return null;
    }
    return detail.episodes.last;
  }

  String _episodeStatusLabel(StoryStatus status) {
    switch (status) {
      case StoryStatus.published:
        return 'Publicado';
      case StoryStatus.archived:
        return 'Arquivado';
      case StoryStatus.draft:
        return 'Rascunho';
    }
  }

  Future<void> _openCollectionAdventure(StoryVaultCollectionItem item) async {
    if (_busyCollectionId != null) {
      return;
    }

    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _busyCollectionId = item.id);
    try {
      final resolver = StoryVaultAdventureResolver(ref.read(storyApiProvider));
      var result = await resolver.resolve(
        accessToken: token,
        collectionId: item.id,
        collectionItem: item,
      );

      if (!mounted) {
        return;
      }

      if (result.code == 'STORY_COLLECTION_DRAFT_EXISTS' &&
          !result.hasStoryTarget) {
        await _loadCollections();
        if (!mounted) {
          return;
        }
        final refreshed = _collectionById(item.id);
        result = await resolver.resolve(
          accessToken: token,
          collectionId: item.id,
          collectionItem: refreshed,
        );
        if (!mounted) {
          return;
        }
      }

      if (!result.hasStoryTarget) {
        UxAnalytics.log(
          'vault_story_open_failed',
          params: <String, Object?>{
            'source': 'vault_card_tap',
            'collection_id': item.id,
            if (result.code != null && result.code!.trim().isNotEmpty)
              'code': result.code,
            if (result.message != null && result.message!.trim().isNotEmpty)
              'message': result.message,
          },
        );
        _showSnackMessage(
          result.message ?? 'Não foi possível abrir a aventura agora.',
        );
        return;
      }

      var targetStoryId = result.storyId!;
      if (result.recoveredFromConflict) {
        await _loadCollections();
        if (!mounted) {
          return;
        }
        final refreshed = _collectionById(item.id);
        final latestRefreshed = refreshed?.latestEpisode;
        if ((refreshed?.draftCount ?? 0) > 0 &&
            latestRefreshed != null &&
            latestRefreshed.status == StoryStatus.draft &&
            latestRefreshed.storyId.trim().isNotEmpty) {
          targetStoryId = latestRefreshed.storyId;
        }
      }

      UxAnalytics.log(
        'vault_story_opened',
        params: <String, Object?>{
          'source': 'vault_card_tap',
          'collection_id': item.id,
          'outcome': result.outcome == StoryVaultAdventureOutcome.draftOpened
              ? 'draft_opened'
              : 'continued_opened',
        },
      );

      context.push(AppRoute.storyRoom(targetStoryId));
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao abrir aventura a partir do card do Baú.',
        error: error,
        stackTrace: stackTrace,
        scope: 'story_vault',
      );
      if (!mounted) {
        return;
      }
      final presentation = describeApiError(error);
      UxAnalytics.log(
        'vault_story_open_failed',
        params: <String, Object?>{
          'source': 'vault_card_tap',
          'collection_id': item.id,
          if (presentation.code != null && presentation.code!.trim().isNotEmpty)
            'code': presentation.code,
          'message': presentation.message,
        },
      );
      _showSnackMessage(presentation.message);
    } finally {
      if (mounted && _busyCollectionId == item.id) {
        setState(() => _busyCollectionId = null);
      }
    }
  }

  Future<String?> _askTargetChildId(String defaultChildId) async {
    final childOptions = _children.isNotEmpty
        ? _children
        : <ChildProfile>[
            ChildProfile(
              id: defaultChildId,
              name: 'Criança atual',
              birthDate: DateTime(2018, 1, 1),
              favoriteThemes: const <String>[],
              isArchived: false,
            ),
          ];
    var selected = defaultChildId;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Repetir aventura'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Criança destino'),
            items: childOptions
                .map(
                  (child) => DropdownMenuItem<String>(
                    value: child.id,
                    child: Text(child.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                selected = value;
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('Criar template'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _duplicateCollectionFromDetail(
    StoryVaultCollectionDetail detail,
  ) async {
    if (_busyCollectionId != null) {
      return;
    }
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final sourceEpisode = _latestEpisodeFromDetail(detail);
    if (sourceEpisode == null) {
      _showSnackMessage('Esta saga ainda não possui capítulos para repetir.');
      return;
    }

    final targetChildId = await _askTargetChildId(detail.child.id);
    if (!mounted || targetChildId == null || targetChildId.isEmpty) {
      return;
    }

    setState(() => _busyCollectionId = detail.id);
    try {
      final created = await ref
          .read(storyApiProvider)
          .duplicateStoryAsTemplate(
            token,
            sourceEpisode.storyId,
            childProfileId: targetChildId,
          );
      if (!mounted) {
        return;
      }
      await _loadCollections();
      if (!mounted) {
        return;
      }
      context.push(AppRoute.storyRoom(created.id));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackMessage(parseDioError(error));
    } finally {
      if (mounted && _busyCollectionId == detail.id) {
        setState(() => _busyCollectionId = null);
      }
    }
  }

  Future<void> _openCollectionActionsSheet(
    StoryVaultCollectionItem item,
  ) async {
    if (_busyCollectionId != null) {
      return;
    }

    final token = _accessToken();
    if (token == null) {
      return;
    }

    UxAnalytics.log(
      'vault_collection_actions_opened',
      params: <String, Object?>{
        'source': 'vault_card_actions',
        'collection_id': item.id,
      },
    );

    setState(() => _busyCollectionId = item.id);
    StoryVaultCollectionDetail? detail;
    try {
      detail = await ref
          .read(storyApiProvider)
          .getStoryVaultCollection(token, item.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackMessage(parseDioError(error));
      return;
    } finally {
      if (mounted && _busyCollectionId == item.id) {
        setState(() => _busyCollectionId = null);
      }
    }

    if (!mounted) {
      return;
    }

    final detailData = detail;
    final dateFormat = DateFormat('dd/MM HH:mm');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detailData.title,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${detailData.child.name} · ${detailData.theme}',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Repetir aventura'),
                  subtitle: const Text('Criar uma cópia para outra criança'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _duplicateCollectionFromDetail(detailData);
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Capítulos',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                if (detailData.episodes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 2, bottom: 8),
                    child: Text('Sem capítulos nesta saga.'),
                  ),
                ...detailData.episodes.reversed.map((episode) {
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(episode.episodeNumber.toString()),
                    ),
                    title: Text(
                      'Ep ${episode.episodeNumber} · ${episode.title}',
                    ),
                    subtitle: Text(
                      '${_episodeStatusLabel(episode.status)} · ${dateFormat.format(episode.updatedAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push(AppRoute.storyRoom(episode.storyId));
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _trackVaultEmptyCta(String cta) {
    UxAnalytics.log(
      'vault_empty_cta_tapped',
      params: <String, Object?>{
        'screen': 'vault',
        'cta': cta,
        'state': _computeVaultState(),
        'source': 'story_vault_screen',
      },
    );
  }

  Future<void> _createQuickStory() async {
    if (_quickCreating) {
      return;
    }

    final token = _accessToken();
    if (token == null) {
      return;
    }

    final startedAt = DateTime.now();
    setState(() => _quickCreating = true);

    UxAnalytics.log(
      'story_create_started',
      params: const <String, Object?>{
        'source': 'story_vault_quick',
        'flow': 'quick',
      },
    );

    try {
      if (_children.isEmpty) {
        await _loadFiltersData();
      }
      if (!mounted) {
        return;
      }

      final selectedChild = selectQuickStoryChild(
        children: _children,
        collections: _collections,
        selectedChildId: _selectedChildId,
      );
      if (selectedChild == null) {
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        UxAnalytics.log(
          'story_create_abandoned',
          params: <String, Object?>{
            'step': 1,
            'source': 'story_vault_quick',
            'flow': 'quick',
            'reason': 'no_child',
            'duration_ms': elapsed,
          },
        );
        _showSnackMessage(
          'Cadastre uma criança em Perfil > Crianças para começar a aventura.',
        );
        return;
      }

      final templates = await ref
          .read(storyApiProvider)
          .listPublishedStoryTemplates(token);

      String? suggestedVirtueId;
      try {
        final suggestion = await ref
            .read(storyApiProvider)
            .suggestVirtue(token, childProfileId: selectedChild.id);
        suggestedVirtueId = suggestion.virtue.id;
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Falha ao sugerir virtude no quick create. Seguindo com fallback.',
          error: error,
          stackTrace: stackTrace,
          scope: 'story_vault',
        );
        // O backend já resolve virtude automaticamente quando necessário.
      }

      final defaults = buildQuickStoryDefaults(
        children: _children,
        collections: _collections,
        templates: templates,
        selectedChildId: _selectedChildId,
        suggestedVirtueId: suggestedVirtueId,
      );

      if (defaults == null) {
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        UxAnalytics.log(
          'story_create_abandoned',
          params: <String, Object?>{
            'step': 1,
            'source': 'story_vault_quick',
            'flow': 'quick',
            'reason': 'defaults_unavailable',
            'duration_ms': elapsed,
          },
        );
        _showSnackMessage('Não foi possível montar uma história rápida agora.');
        return;
      }

      UxAnalytics.log(
        'story_create_step_completed',
        params: <String, Object?>{
          'step': 1,
          'source': 'story_vault_quick',
          'flow': 'quick',
          'child_id': defaults.child.id,
        },
      );

      final created = await ref
          .read(storyRoomControllerProvider.notifier)
          .createSession(
            childProfileId: defaults.child.id,
            titleDraft: defaults.titleDraft,
            theme: defaults.theme,
            scenario: defaults.scenario,
            characters: defaults.characters,
            objective: defaults.objective,
            startMode: StoryMode.parentNarrator,
            virtueId: defaults.virtueId,
            sourceTemplateId: defaults.sourceTemplateId,
          );

      if (!mounted) {
        return;
      }

      if (created == null) {
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        UxAnalytics.log(
          'story_create_abandoned',
          params: <String, Object?>{
            'step': 2,
            'source': 'story_vault_quick',
            'flow': 'quick',
            'reason': 'create_failed',
            'child_id': defaults.child.id,
            'duration_ms': elapsed,
          },
        );
        final error = ref.read(storyRoomControllerProvider).error;
        _showSnackMessage(error ?? 'Não foi possível criar a história rápida.');
        return;
      }

      UxAnalytics.log(
        'story_create_step_completed',
        params: <String, Object?>{
          'step': 2,
          'source': 'story_vault_quick',
          'flow': 'quick',
          'child_id': defaults.child.id,
        },
      );

      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      UxAnalytics.log(
        'story_create_step_completed',
        params: <String, Object?>{
          'step': 3,
          'source': 'story_vault_quick',
          'flow': 'quick',
          'child_id': defaults.child.id,
          'duration_ms': elapsed,
        },
      );
      context.push(AppRoute.storyRoom(created.id));
      final userId = ref.read(authControllerProvider).user?.id;
      if (userId != null) {
        try {
          await ref.read(createStoryWizardDraftStoreProvider).clear(userId);
        } catch (error, stackTrace) {
          AppLogger.warn(
            'Falha ao limpar rascunho local após quick create.',
            error: error,
            stackTrace: stackTrace,
            scope: 'story_vault',
          );
        }
      }
      if (mounted) {
        setState(() {
          _resumeDraft = null;
        });
      }
    } catch (error) {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      UxAnalytics.log(
        'story_create_abandoned',
        params: <String, Object?>{
          'step': 1,
          'source': 'story_vault_quick',
          'flow': 'quick',
          'reason': 'request_error',
          'duration_ms': elapsed,
        },
      );
      if (!mounted) {
        return;
      }
      _showSnackMessage(parseDioError(error));
    } finally {
      if (mounted) {
        setState(() => _quickCreating = false);
      }
    }
  }

  Widget _buildCreationActions({bool trackAsEmptyCta = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ViscondePrimaryCta(
          onPressed: _quickCreating
              ? null
              : () {
                  if (trackAsEmptyCta) {
                    _trackVaultEmptyCta('quick_create');
                  }
                  _createQuickStory();
                },
          icon: Icons.flash_on_rounded,
          label: _quickCreating
              ? 'Criando história rápida...'
              : 'Criar história rápida (1 toque)',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _quickCreating
              ? null
              : () {
                  if (trackAsEmptyCta) {
                    _trackVaultEmptyCta('create_with_details');
                  }
                  _openCreateWithResume(resume: false);
                },
          icon: const Icon(Icons.tune),
          label: const Text('Criar com detalhes'),
        ),
        const SizedBox(height: 8),
        Text(
          'Dica: você pode publicar mesmo com poucas etapas. O app completa as iniciais automaticamente.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildInitialSkeleton() {
    return Column(
      children: [
        const ViscondeSkeletonCard(
          leading: ViscondeSkeletonBox(height: 72, width: 72, radius: 36),
          lines: 3,
        ),
        const SizedBox(height: 12),
        const ViscondeSkeletonCard(lines: 5),
        const SizedBox(height: 12),
        ...List<Widget>.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: ViscondeSkeletonCard(lines: 3),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersCard(DateFormat dateFormat) {
    final activeCount = _activeFiltersCount;
    final activeLabels = _activeFilterLabels(dateFormat);
    final headerSubtitle = activeCount == 0
        ? 'Refine por criança, virtude e período.'
        : '$activeCount filtro(s) ativo(s)';

    return ViscondeGlassCard(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: Column(
          children: [
            InkWell(
              key: const Key('vault_filter_accordion_header'),
              borderRadius: BorderRadius.circular(context.viscondeRadii.md),
              onTap: () {
                setState(() => _isFilterExpanded = !_isFilterExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            headerSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_hasActiveFilters)
                      TextButton(
                        onPressed: (_loadingCollections || _loadingFilters)
                            ? null
                            : _clearFiltersAndReload,
                        child: const Text('Limpar'),
                      ),
                    Icon(
                      _isFilterExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _isFilterExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeIn,
              sizeCurve: Curves.easeInOut,
              firstChild: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: activeLabels.isEmpty
                      ? Text(
                          'Nenhum filtro ativo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: activeLabels
                              .map(
                                (label) => Chip(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  label: Text(label),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
              secondChild: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _themeController,
                          decoration: InputDecoration(
                            labelText: 'Filtro por tema',
                            suffixIcon: IconButton(
                              onPressed: _loadCollections,
                              icon: const Icon(Icons.search),
                            ),
                          ),
                          onSubmitted: (_) => _loadCollections(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loadingFilters)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedChildId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Criança',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todas'),
                            ),
                            ..._children.map(
                              (child) => DropdownMenuItem<String?>(
                                value: child.id,
                                child: Text(child.name),
                              ),
                            ),
                          ],
                          onChanged: (value) async {
                            setState(() => _selectedChildId = value);
                            await _loadCollections();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedVirtueId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Virtude',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todas'),
                            ),
                            ..._virtues.map(
                              (virtue) => DropdownMenuItem<String?>(
                                value: virtue.id,
                                child: Text(virtue.name),
                              ),
                            ),
                          ],
                          onChanged: (value) async {
                            setState(() => _selectedVirtueId = value);
                            await _loadCollections();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromDate,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _dateFrom == null
                                ? 'Data inicial'
                                : 'De ${dateFormat.format(_dateFrom!)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickToDate,
                          icon: const Icon(Icons.event),
                          label: Text(
                            _dateTo == null
                                ? 'Data final'
                                : 'Até ${dateFormat.format(_dateTo!)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _favoriteOnly,
                          onChanged: (value) async {
                            setState(() => _favoriteOnly = value);
                            await _loadCollections();
                          },
                          title: const Text(
                            'Somente favoritas',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final filtered = _hasActiveFilters;
    final title = filtered
        ? UiStateCopy.vaultFilteredEmptyTitle
        : UiStateCopy.vaultEmptyTitle;
    final description = filtered
        ? UiStateCopy.vaultFilteredEmptyDescription
        : UiStateCopy.vaultEmptyDescription;

    return ViscondeContentState.empty(
      title: title,
      description: description,
      primaryActionLabel: filtered
          ? 'Limpar filtros'
          : 'Criar história rápida (1 toque)',
      onPrimaryAction: filtered
          ? () {
              _trackVaultEmptyCta('clear_filters');
              _clearFiltersAndReload();
            }
          : () {
              _trackVaultEmptyCta('quick_create');
              _createQuickStory();
            },
      secondaryActionLabel: filtered
          ? 'Tentar novamente'
          : 'Criar com detalhes',
      onSecondaryAction: filtered
          ? () {
              _trackVaultEmptyCta('retry');
              _retryVaultLoad();
            }
          : () {
              _trackVaultEmptyCta('create_with_details');
              _openCreateWithResume(resume: false);
            },
      mascotPose: filtered
          ? ViscondeMascotPose.enchantedHearts
          : ViscondeMascotPose.readingBook,
    );
  }

  Widget _buildResumeDraftCard() {
    final draft = _resumeDraft;
    if (draft == null) {
      return const SizedBox.shrink();
    }

    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ViscondeSectionTitle(
            title: 'Rascunho em andamento',
            subtitle: 'Retome sua criação de onde parou.',
          ),
          const SizedBox(height: 8),
          Text('Passo ${draft.currentStep + 1} de 3'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openCreateWithResume(resume: true),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continuar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _discardResumeDraft,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Descartar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final hasBlockingError = _blockingError != null && _collections.isEmpty;

    return RefreshIndicator(
      onRefresh: _retryVaultLoad,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 12,
            ),
            sliver: SliverToBoxAdapter(
              child: ViscondeHeroBanner(
                title: 'Baú de Aventuras',
                subtitle:
                    '${_collections.length} sagas encontradas · toque e continue em 1 toque',
                assetPath: ViscondeArtRegistry.resolve(
                  ViscondeArtKey.heroTreasure,
                ),
                variant: ViscondeHeroBannerVariant.compactModern,
                showMascot: true,
                mascotPose: ViscondeMascotPose.readingBook,
              ),
            ),
          ),

          if (_loadingInitial)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _buildInitialSkeleton()),
            ),

          if (!_loadingInitial)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _buildFiltersCard(dateFormat)),
            ),

          if (!_loadingInitial && hasBlockingError) ...[
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              sliver: SliverToBoxAdapter(
                child: ViscondeContentState.error(
                  title: UiStateCopy.genericErrorTitle,
                  description:
                      _blockingError ?? UiStateCopy.genericErrorDescription,
                  primaryActionLabel: 'Tentar novamente',
                  onPrimaryAction: _retryVaultLoad,
                  secondaryActionLabel: 'Criar história rápida (1 toque)',
                  onSecondaryAction: () {
                    _trackVaultEmptyCta('quick_create_error');
                    _createQuickStory();
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              sliver: SliverToBoxAdapter(
                child: _buildCreationActions(trackAsEmptyCta: true),
              ),
            ),
          ],

          if (!_loadingInitial && !hasBlockingError) ...[
            if (_inlineError != null)
              SliverPadding(
                padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                sliver: SliverToBoxAdapter(
                  child: ViscondeContentState.error(
                    title: UiStateCopy.genericErrorTitle,
                    description: _inlineError!,
                    primaryActionLabel: 'Tentar novamente',
                    onPrimaryAction: _retryVaultLoad,
                  ),
                ),
              ),
            if (_loadingCollections)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                sliver: SliverToBoxAdapter(child: LinearProgressIndicator()),
              ),
          ],

          if (!_loadingInitial && _resumeDraft != null && !hasBlockingError)
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              sliver: SliverToBoxAdapter(child: _buildResumeDraftCard()),
            ),

          if (!_loadingInitial && !hasBlockingError)
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              sliver: SliverToBoxAdapter(child: _buildCreationActions()),
            ),

          if (!_loadingInitial && !hasBlockingError && _selectedChildId != null)
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              sliver: SliverToBoxAdapter(
                child: ViscondePrimaryCta(
                  onPressed: _generateMonthlyBook,
                  icon: Icons.picture_as_pdf,
                  label: 'Gerar Livro do Mês',
                ),
              ),
            ),

          if (!_loadingInitial && !hasBlockingError && _collections.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              sliver: SliverToBoxAdapter(child: _buildEmptyState()),
            ),

          if (!_loadingInitial && !hasBlockingError && _collections.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Toque em uma saga para continuar direto.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),

          if (!_loadingInitial && !hasBlockingError && _collections.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
                bottom: 32,
              ),
              sliver: SliverList.builder(
                itemCount: _collections.length,
                itemBuilder: (context, index) {
                  final item = _collections[index];
                  final isBusy = _isCollectionBusy(item.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ViscondeStoryRowCard(
                      onTap: isBusy
                          ? null
                          : () => _openCollectionAdventure(item),
                      title: item.title,
                      badgeLabel: item.virtue?.name ?? item.theme,
                      backgroundAsset: ViscondeArtRegistry.resolve(
                        item.isFavorite
                            ? ViscondeArtKey.heroCastle
                            : ViscondeArtKey.heroForest,
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBusy)
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              onPressed: () =>
                                  _openCollectionActionsSheet(item),
                              icon: const Icon(Icons.more_horiz),
                              tooltip: 'Ações da saga',
                            ),
                          IconButton(
                            onPressed: isBusy
                                ? null
                                : () => _toggleFavorite(item),
                            icon: Icon(
                              item.isFavorite ? Icons.star : Icons.star_border,
                              color: item.isFavorite
                                  ? Colors.amber.shade700
                                  : null,
                            ),
                            tooltip: item.isFavorite
                                ? 'Desfavoritar'
                                : 'Favoritar',
                          ),
                          Text(
                            '${item.episodesCount} ep',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
