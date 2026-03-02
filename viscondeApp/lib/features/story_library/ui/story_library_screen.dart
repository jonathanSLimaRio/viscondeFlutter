import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ViscondeHeroBanner(
            title: 'Biblioteca Clássica',
            subtitle: 'Visão por capítulos individuais.',
            assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroTreasure),
            showMascot: true,
            mascotPose: ViscondeMascotPose.readingBook,
          ),
          const SizedBox(height: 12),
          ViscondePrimaryCta(
            onPressed: () => context.push('/stories/new'),
            icon: Icons.auto_stories,
            label: 'Nova Sala de História',
          ),
          const SizedBox(height: 12),
          ViscondeGlassCard(
            child: SegmentedButton<StoryStatus?>(
              segments: const [
                ButtonSegment<StoryStatus?>(value: null, label: Text('Todos')),
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
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _stories.isEmpty)
            ViscondeGlassCard(
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
          ..._stories.map(
            (story) => ViscondeGlassCard(
              child: ListTile(
                onTap: () => context.push('/stories/${story.id}/room'),
                leading: const CircleAvatar(
                  child: Icon(Icons.menu_book_outlined),
                ),
                title: Text(story.title),
                subtitle: Text(
                  '${story.childName} · ${_statusLabel(story.status)} · ${story.stepsCount} etapas'
                  '\nSessao: ${story.sessionKind == StorySessionKind.remote ? 'Remota' : 'Presencial'}'
                  '${story.virtue != null ? '\nVirtude: ${story.virtue!.name}' : ''}'
                  '\nAtualizado em ${DateFormat('dd/MM HH:mm').format(story.updatedAt)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
