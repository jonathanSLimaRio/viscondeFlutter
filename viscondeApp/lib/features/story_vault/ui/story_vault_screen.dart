import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../../story_room/models/story_models.dart';

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
            trailing: ViscondeAvatarBadge(
              imageAsset: ViscondeArtRegistry.resolve(
                ViscondeArtKey.avatarChild,
              ),
            ),
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
                        decoration: const InputDecoration(labelText: 'Crianca'),
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
                              : 'Ate ${dateFormat.format(_dateTo!)}',
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
          ViscondePrimaryCta(
            onPressed: () => context.push('/stories/new'),
            icon: Icons.auto_stories_outlined,
            label: 'Criar nova história',
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _collections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Nenhuma saga encontrada com os filtros atuais.'),
            ),
          ..._collections.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ViscondeStoryRowCard(
                onTap: () => context.push('/vault/${item.id}'),
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
