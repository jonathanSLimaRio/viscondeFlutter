import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/avatar_presets.dart';
import '../../../shared/providers.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';
import '../../story_room/models/story_models.dart';
import '../game_adventure_session_controller.dart';

class GameBlankScreen extends ConsumerStatefulWidget {
  const GameBlankScreen({super.key});

  @override
  ConsumerState<GameBlankScreen> createState() => _GameBlankScreenState();
}

class _GameBlankScreenState extends ConsumerState<GameBlankScreen> {
  bool _loading = true;
  bool _opening = false;
  String? _error;
  String? _selectedChildId;
  StorySessionModel? _activeStory;
  List<ChildProfile> _children = const <ChildProfile>[];
  bool _openedTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  Future<void> _bootstrap() async {
    await _reloadAll();
  }

  Future<void> _reloadAll({String? preferredChildId}) async {
    final token = _accessToken();
    if (token == null) {
      final authState = ref.read(authControllerProvider);
      if (authState.status == AuthStatus.loading) {
        Future<void>.delayed(const Duration(milliseconds: 180), () {
          if (!mounted) {
            return;
          }
          _reloadAll(preferredChildId: preferredChildId);
        });
        return;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _children = const <ChildProfile>[];
          _activeStory = null;
          _error = 'Sessão expirada. Faça login novamente.';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final children = await ref.read(childrenApiProvider).listChildren(token);
      if (!mounted) {
        return;
      }

      String? selectedChildId;
      if (preferredChildId != null &&
          children.any((child) => child.id == preferredChildId)) {
        selectedChildId = preferredChildId;
      } else if (_selectedChildId != null &&
          children.any((child) => child.id == _selectedChildId)) {
        selectedChildId = _selectedChildId;
      } else if (children.isNotEmpty) {
        selectedChildId = children.first.id;
      }

      final story = await _resolveActiveStory(
        token,
        selectedChildId: selectedChildId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _children = children;
        _selectedChildId = story?.childProfileId ?? selectedChildId;
        _activeStory = story;
        _loading = false;
        _error = null;
      });
      _trackOpenedIfNeeded();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = parseDioError(error);
      });
      _trackOpenedIfNeeded();
    }
  }

  Future<StorySessionModel?> _resolveActiveStory(
    String token, {
    required String? selectedChildId,
  }) async {
    final storyApi = ref.read(storyApiProvider);
    final adventureState = ref.read(gameAdventureSessionControllerProvider);

    Future<StorySessionModel?> loadSessionById(String? storyId) async {
      final resolved = storyId?.trim();
      if (resolved == null || resolved.isEmpty) {
        return null;
      }
      try {
        return await storyApi.getStorySession(token, resolved);
      } catch (_) {
        return null;
      }
    }

    final fromSessionState = await loadSessionById(adventureState.storyId);
    if (fromSessionState != null &&
        (selectedChildId == null ||
            fromSessionState.childProfileId == selectedChildId)) {
      return fromSessionState;
    }

    Future<StorySessionModel?> loadLatestByStatus(StoryStatus status) async {
      final items = await storyApi.listStories(
        token,
        childProfileId: selectedChildId,
        status: status,
      );

      if (items.isEmpty) {
        return null;
      }

      final ordered = [...items]
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

      for (final item in ordered) {
        final loaded = await loadSessionById(item.id);
        if (loaded != null) {
          return loaded;
        }
      }
      return null;
    }

    final latestDraft = await loadLatestByStatus(StoryStatus.draft);
    if (latestDraft != null) {
      return latestDraft;
    }

    return loadLatestByStatus(StoryStatus.published);
  }

  void _trackOpenedIfNeeded() {
    if (_openedTracked) {
      return;
    }
    _openedTracked = true;

    final story = _activeStory;
    String state;
    if (_error != null) {
      state = 'error';
    } else if (_children.isEmpty) {
      state = 'empty_children';
    } else if (story == null) {
      state = 'empty_story';
    } else {
      state = 'ready';
    }

    UxAnalytics.log(
      'game_home_opened',
      params: <String, Object?>{
        'source': 'game_blank_screen',
        'state': state,
        'child_id': _selectedChildId,
        if (story != null) 'story_id': story.id,
        if (story != null) 'status': story.status.name,
      },
    );
  }

  Future<void> _openStoryOrContinue() async {
    final token = _accessToken();
    final story = _activeStory;
    if (token == null || story == null || _opening) {
      return;
    }

    setState(() => _opening = true);

    try {
      if (story.status == StoryStatus.published) {
        UxAnalytics.log(
          'adventure_resume_clicked',
          params: <String, Object?>{
            'source': 'game_blank_screen',
            'story_id': story.id,
            'child_id': story.childProfileId,
            'status': story.status.name,
            'action': 'continue',
          },
        );
        final continued = await ref
            .read(storyApiProvider)
            .continueStory(token, story.id);
        if (!mounted) {
          return;
        }

        ref
            .read(gameAdventureSessionControllerProvider.notifier)
            .setFromStory(
              storyId: continued.id,
              title: continued.title.trim().isEmpty
                  ? continued.titleDraft
                  : continued.title,
              childProfileId: continued.childProfileId,
              theme: continued.theme,
              biome: continued.gameSummary?.biome ?? continued.game?.map.biome,
            );
        await _reloadAll(preferredChildId: continued.childProfileId);
        if (!mounted) {
          return;
        }
        context.push(AppRoute.storyRoom(continued.id));
      } else {
        UxAnalytics.log(
          'adventure_resume_clicked',
          params: <String, Object?>{
            'source': 'game_blank_screen',
            'story_id': story.id,
            'child_id': story.childProfileId,
            'status': story.status.name,
            'action': 'open_draft',
          },
        );
        ref
            .read(gameAdventureSessionControllerProvider.notifier)
            .setFromStory(
              storyId: story.id,
              title: story.title.trim().isEmpty
                  ? story.titleDraft
                  : story.title,
              childProfileId: story.childProfileId,
              theme: story.theme,
              biome: story.gameSummary?.biome ?? story.game?.map.biome,
            );
        if (!mounted) {
          return;
        }
        context.push(AppRoute.storyRoom(story.id));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  void _openAvatarEditor() {
    UxAnalytics.log(
      'avatar_editor_opened',
      params: <String, Object?>{
        'source': 'game_blank_screen',
        'target': 'family',
        if (_selectedChildId != null) 'child_id': _selectedChildId,
      },
    );
    context.push(
      AppRoute.avatarEditorPath(
        source: 'game_blank_screen',
        childId: _selectedChildId,
      ),
    );
  }

  void _onChildSelected(String childId) {
    if (_selectedChildId == childId || _loading) {
      return;
    }
    _reloadAll(preferredChildId: childId);
  }

  ViscondeArtKey _backgroundArtForStory(StorySessionModel story) {
    final biome =
        (story.gameSummary?.biome ?? story.game?.map.biome ?? 'FOREST')
            .toUpperCase();
    switch (biome) {
      case 'CASTLE':
        return ViscondeArtKey.heroCastle;
      case 'UNDERWATER':
        return ViscondeArtKey.heroUnderwater;
      case 'SPACE':
        return ViscondeArtKey.heroSpace;
      case 'TREASURE':
        return ViscondeArtKey.heroTreasure;
      case 'FOREST':
      default:
        return ViscondeArtKey.heroForest;
    }
  }

  int _currentNode(StorySessionModel story) {
    final totalNodes =
        story.gameSummary?.totalNodes ?? story.game?.map.totalNodes ?? 12;
    if (story.status == StoryStatus.published) {
      return math.max(1, math.min(totalNodes, story.steps.length));
    }
    return math.max(1, math.min(totalNodes, story.steps.length + 1));
  }

  Widget _buildAvatar({
    required String label,
    required String? networkImageUrl,
    required bool isParent,
    required String presetKey,
    required int variant,
    required String accent,
  }) {
    final accentColor = resolveAvatarAccentColor(accent);
    final assetPath = resolveAvatarAsset(
      isParent: isParent,
      avatarPresetKey: presetKey,
      avatarVariant: variant,
    );

    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 3),
          ),
          child: ClipOval(
            child: networkImageUrl != null && networkImageUrl.trim().isNotEmpty
                ? Image.network(
                    networkImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Image.asset(assetPath, fit: BoxFit.cover),
                  )
                : Image.asset(assetPath, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildNoChildren() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ViscondeGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.child_care_outlined, size: 42),
              const SizedBox(height: 12),
              Text(
                'Nenhuma criança cadastrada',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Cadastre uma criança para iniciar novas aventuras.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    context.go(AppRoute.homePath(tab: HomeTab.profile)),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Ir para Perfil > Crianças'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAdventure() {
    final selectedChild = _children.firstWhere(
      (child) => child.id == _selectedChildId,
      orElse: () => _children.first,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ViscondeGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_outlined, size: 42),
              const SizedBox(height: 12),
              Text(
                'Nenhuma aventura ativa',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Crie uma aventura para ${selectedChild.name} e continue no modo Game.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push(AppRoute.storyCreate),
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('Criar aventura'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _children
            .map((child) {
              final selected = _selectedChildId == child.id;
              return ChoiceChip(
                selected: selected,
                label: Text(child.name),
                onSelected: (_) => _onChildSelected(child.id),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ViscondeContentState.error(
            title: 'Não foi possível carregar o Game',
            description: _error!,
            primaryActionLabel: 'Tentar novamente',
            onPrimaryAction: () {
              _reloadAll();
            },
          ),
        ),
      );
    }

    if (_children.isEmpty) {
      return _buildNoChildren();
    }

    final story = _activeStory;
    if (story == null) {
      return Material(
        type: MaterialType.transparency,
        child: RefreshIndicator(
          onRefresh: () => _reloadAll(),
          child: ListView(
            children: [_buildChildSelector(), _buildNoAdventure()],
          ),
        ),
      );
    }

    final selectedChild = _children.firstWhere(
      (child) => child.id == story.childProfileId,
      orElse: () => _children.first,
    );
    final storyTitle = story.title.trim().isEmpty
        ? story.titleDraft
        : story.title;
    final user = ref.watch(authControllerProvider).user;
    final totalNodes =
        story.gameSummary?.totalNodes ?? story.game?.map.totalNodes ?? 12;
    final currentNode =
        story.gameSummary?.currentNodeIndex ?? _currentNode(story);
    final progressPercent =
        story.gameSummary?.progressPercent ??
        (totalNodes <= 0 ? 0 : (currentNode / totalNodes));
    final turnLabel = story.currentMode == StoryMode.parentNarrator
        ? 'Agora é o pai'
        : 'Agora é a criança';

    return Material(
      type: MaterialType.transparency,
      child: RefreshIndicator(
        onRefresh: () => _reloadAll(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildChildSelector()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: AssetImage(
                        ViscondeArtRegistry.resolve(
                          _backgroundArtForStory(story),
                        ),
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.28),
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.status == StoryStatus.published
                              ? 'Capítulo concluído'
                              : 'Sua aventura está pronta',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          storyTitle,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildAvatar(
                              label: 'Pai',
                              networkImageUrl: user?.imageUrl,
                              isParent: true,
                              presetKey: user?.avatarPresetKey ?? 'guardian',
                              variant: user?.avatarVariant ?? 1,
                              accent: user?.avatarAccent ?? 'amber',
                            ),
                            _buildAvatar(
                              label: selectedChild.name,
                              networkImageUrl: selectedChild.avatarUrl,
                              isParent: false,
                              presetKey: selectedChild.avatarPresetKey,
                              variant: selectedChild.avatarVariant,
                              accent: selectedChild.avatarAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Nó $currentNode/$totalNodes · $turnLabel',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                              ),
                              Text(
                                story.theme,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: progressPercent.clamp(0.0, 1.0).toDouble(),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: Colors.white.withValues(alpha: 0.24),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFBC02D),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _opening ? null : _openStoryOrContinue,
                            icon: Icon(
                              story.status == StoryStatus.published
                                  ? Icons.playlist_add_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(
                              _opening
                                  ? 'Abrindo...'
                                  : story.status == StoryStatus.published
                                  ? 'Criar próximo capítulo'
                                  : 'Entrar na aventura',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openAvatarEditor,
                            icon: const Icon(Icons.palette_outlined),
                            label: const Text('Trocar avatares'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
