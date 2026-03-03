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
          'Cadastre uma criança na aba Crianças para começar a aventura.',
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
              : 'Criar história rápida',
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
    return ViscondeGlassCard(
      child: Column(
        children: [
          const ViscondeSectionTitle(
            title: 'Filtros',
            subtitle: 'Refine por criança, virtude e período.',
          ),
          const SizedBox(height: 10),
          TextField(
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
                  decoration: const InputDecoration(labelText: 'Criança'),
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
                  decoration: const InputDecoration(labelText: 'Virtude'),
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
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _favoriteOnly,
            onChanged: (value) async {
              setState(() => _favoriteOnly = value);
              await _loadCollections();
            },
            title: const Text('Somente favoritas'),
          ),
        ],
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
      primaryActionLabel: filtered ? 'Limpar filtros' : 'Criar história rápida',
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ViscondeHeroBanner(
            title: 'Baú de Aventuras',
            subtitle: '${_collections.length} sagas encontradas',
            assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroTreasure),
            showMascot: true,
            mascotPose: ViscondeMascotPose.readingBook,
          ),
          const SizedBox(height: 12),
          if (_loadingInitial) _buildInitialSkeleton(),
          if (!_loadingInitial) _buildFiltersCard(dateFormat),
          if (!_loadingInitial && hasBlockingError) ...[
            const SizedBox(height: 12),
            ViscondeContentState.error(
              title: UiStateCopy.genericErrorTitle,
              description:
                  _blockingError ?? UiStateCopy.genericErrorDescription,
              primaryActionLabel: 'Tentar novamente',
              onPrimaryAction: _retryVaultLoad,
              secondaryActionLabel: 'Criar história rápida',
              onSecondaryAction: () {
                _trackVaultEmptyCta('quick_create_error');
                _createQuickStory();
              },
            ),
            const SizedBox(height: 12),
            _buildCreationActions(trackAsEmptyCta: true),
          ],
          if (!_loadingInitial && !hasBlockingError) ...[
            if (_inlineError != null) ...[
              ViscondeContentState.error(
                title: UiStateCopy.genericErrorTitle,
                description: _inlineError!,
                primaryActionLabel: 'Tentar novamente',
                onPrimaryAction: _retryVaultLoad,
              ),
              const SizedBox(height: 12),
            ],
            if (_loadingCollections)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
          ],
          const SizedBox(height: 12),
          if (!_loadingInitial &&
              _resumeDraft != null &&
              !hasBlockingError) ...[
            _buildResumeDraftCard(),
            const SizedBox(height: 12),
          ],
          if (!_loadingInitial && !hasBlockingError) _buildCreationActions(),
          if (!_loadingInitial &&
              !hasBlockingError &&
              _selectedChildId != null) ...[
            const SizedBox(height: 12),
            ViscondePrimaryCta(
              onPressed: _generateMonthlyBook,
              icon: Icons.picture_as_pdf,
              label: 'Gerar Livro do Mês',
            ),
          ],
          const SizedBox(height: 12),
          if (!_loadingInitial && !hasBlockingError && _collections.isEmpty)
            _buildEmptyState(),
          if (!_loadingInitial && !hasBlockingError)
            ..._collections.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ViscondeStoryRowCard(
                  onTap: () => context.push(AppRoute.vaultDetail(item.id)),
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
                      IconButton(
                        onPressed: () => _toggleFavorite(item),
                        icon: Icon(
                          item.isFavorite ? Icons.star : Icons.star_border,
                          color: item.isFavorite ? Colors.amber.shade700 : null,
                        ),
                        tooltip: item.isFavorite ? 'Desfavoritar' : 'Favoritar',
                      ),
                      Text(
                        '${item.episodesCount} ep',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
