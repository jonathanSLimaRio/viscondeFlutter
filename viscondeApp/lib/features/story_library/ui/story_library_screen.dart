import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../../story_room/models/story_models.dart';

class StoryLibraryScreen extends ConsumerStatefulWidget {
  const StoryLibraryScreen({super.key});

  @override
  ConsumerState<StoryLibraryScreen> createState() => _StoryLibraryScreenState();
}

class _StoryLibraryScreenState extends ConsumerState<StoryLibraryScreen> {
  List<StoryListItem> _stories = const [];
  bool _loading = false;
  StoryStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStories();
    });
  }

  Future<void> _loadStories() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    setState(() => _loading = true);

    try {
      final stories = await ref
          .read(storyApiProvider)
          .listStories(token, status: _statusFilter);

      if (!mounted) {
        return;
      }

      setState(() {
        _stories = stories;
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

  String _statusLabel(StoryStatus status) {
    switch (status) {
      case StoryStatus.published:
        return 'Publicado';
      case StoryStatus.archived:
        return 'Arquivado';
      case StoryStatus.draft:
        return 'Rascunho';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStories,
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
                title: 'Biblioteca Clássica',
                subtitle: 'Visão por capítulos individuais.',
                assetPath: ViscondeArtRegistry.resolve(
                  ViscondeArtKey.heroTreasure,
                ),
                showMascot: true,
                mascotPose: ViscondeMascotPose.readingBook,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: ViscondePrimaryCta(
                onPressed: () => context.push(AppRoute.storyCreate),
                icon: Icons.auto_stories,
                label: 'Nova Sala de História',
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
            sliver: SliverToBoxAdapter(
              child: ViscondeGlassCard(
                child: SegmentedButton<StoryStatus?>(
                  segments: const [
                    ButtonSegment<StoryStatus?>(
                      value: null,
                      label: Text('Todos'),
                    ),
                    ButtonSegment<StoryStatus?>(
                      value: StoryStatus.draft,
                      label: Text('Rascunhos'),
                    ),
                    ButtonSegment<StoryStatus?>(
                      value: StoryStatus.published,
                      label: Text('Publicados'),
                    ),
                  ],
                  selected: <StoryStatus?>{_statusFilter},
                  onSelectionChanged: (values) {
                    setState(() {
                      _statusFilter = values.first;
                    });
                    _loadStories();
                  },
                ),
              ),
            ),
          ),

          if (_loading)
            const SliverPadding(
              padding: EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          if (!_loading && _stories.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              sliver: SliverToBoxAdapter(
                child: ViscondeGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        const ViscondeMascot(
                          pose: ViscondeMascotPose.readingBook,
                          size: 180,
                          glow: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhuma história encontrada.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Publique um capítulo para preencher sua biblioteca.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (!_loading && _stories.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
                bottom: 32,
              ),
              sliver: SliverList.builder(
                itemCount: _stories.length,
                itemBuilder: (context, index) {
                  final story = _stories[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ViscondeGlassCard(
                      child: ListTile(
                        onTap: () => context.push(AppRoute.storyRoom(story.id)),
                        leading: const CircleAvatar(
                          child: Icon(Icons.menu_book_outlined),
                        ),
                        title: Text(story.title),
                        subtitle: Text(
                          '${story.childName} · ${_statusLabel(story.status)} · ${story.stepsCount} etapas'
                          '\nSessão: ${story.sessionKind == StorySessionKind.remote ? 'Remota' : 'Presencial'}'
                          '${story.virtue != null ? '\nVirtude: ${story.virtue!.name}' : ''}'
                          '\nAtualizado em ${DateFormat('dd/MM HH:mm').format(story.updatedAt)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
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
