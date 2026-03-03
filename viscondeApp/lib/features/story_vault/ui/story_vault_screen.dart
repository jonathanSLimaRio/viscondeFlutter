import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_route.dart';
import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';
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

  bool _loading = false;
  bool _loadingFilters = false;
  bool _favoriteOnly = false;
  bool _quickCreating = false;

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
    await _loadFiltersData();
    await _loadCollections();
  }

  Future<void> _loadFiltersData() async {
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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loadingFilters = false);
      }
    }
  }

  Future<void> _loadCollections() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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

    setState(() => _loading = true);
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
      if (mounted) setState(() => _loading = false);
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

  void _showSnackMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      } catch (_) {
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

  Widget _buildCreationActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ViscondePrimaryCta(
          onPressed: _quickCreating ? null : _createQuickStory,
          icon: Icons.flash_on_rounded,
          label: _quickCreating
              ? 'Criando história rápida...'
              : 'Criar história rápida',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _quickCreating
              ? null
              : () => context.push(AppRoute.storyCreate),
          icon: const Icon(Icons.tune),
          label: const Text('Criar com detalhes'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return RefreshIndicator(
      onRefresh: _loadCollections,
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
          ViscondeGlassCard(
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
          ),
          const SizedBox(height: 12),
          _buildCreationActions(),
          if (_selectedChildId != null) ...[
            const SizedBox(height: 12),
            ViscondePrimaryCta(
              onPressed: _generateMonthlyBook,
              icon: Icons.picture_as_pdf,
              label: 'Gerar Livro do Mês',
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _collections.isEmpty)
            ViscondeGlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      'Seu baú está vazio',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const ViscondeMascot(
                      pose: ViscondeMascotPose.readingBook,
                      size: 180,
                      glow: true,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crie a primeira aventura e comece sua coleção.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    _buildCreationActions(),
                  ],
                ),
              ),
            ),
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
