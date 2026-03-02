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

class StoryVaultDetailScreen extends ConsumerStatefulWidget {
  const StoryVaultDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<StoryVaultDetailScreen> createState() =>
      _StoryVaultDetailScreenState();
}

class _StoryVaultDetailScreenState
    extends ConsumerState<StoryVaultDetailScreen> {
  StoryVaultCollectionDetail? _detail;
  List<ChildProfile> _children = const [];
  bool _loading = false;
  bool _working = false;

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadDetail(), _loadChildren()]);
  }

  Future<void> _loadChildren() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    try {
      final children = await ref.read(childrenApiProvider).listChildren(token);
      if (!mounted) {
        return;
      }
      setState(() => _children = children);
    } catch (_) {
      // Não bloqueia a tela de detalhe.
    }
  }

  Future<void> _loadDetail() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final detail = await ref
          .read(storyApiProvider)
          .getStoryVaultCollection(token, widget.collectionId);
      if (!mounted) {
        return;
      }
      setState(() => _detail = detail);
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

  StoryVaultEpisodeDetail? _latestPublishedEpisode() {
    final episodes = _detail?.episodes ?? const <StoryVaultEpisodeDetail>[];
    for (final episode in episodes.reversed) {
      if (episode.status == StoryStatus.published) {
        return episode;
      }
    }
    return null;
  }

  StoryVaultEpisodeDetail? _latestEpisode() {
    final episodes = _detail?.episodes ?? const <StoryVaultEpisodeDetail>[];
    if (episodes.isEmpty) {
      return null;
    }
    return episodes.last;
  }

  Future<void> _toggleFavorite() async {
    final token = _accessToken();
    final detail = _detail;
    if (token == null || detail == null) {
      return;
    }

    setState(() => _working = true);
    try {
      await ref
          .read(storyApiProvider)
          .setStoryVaultFavorite(
            token,
            detail.id,
            isFavorite: !detail.isFavorite,
          );
      await _loadDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _continueAdventure() async {
    final token = _accessToken();
    final sourceEpisode = _latestPublishedEpisode();
    if (token == null || sourceEpisode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E necessario ao menos um episodio publicado para continuar a aventura.',
          ),
        ),
      );
      return;
    }

    setState(() => _working = true);
    try {
      final story = await ref
          .read(storyApiProvider)
          .continueStory(token, sourceEpisode.storyId);
      if (!mounted) {
        return;
      }
      context.push('/stories/${story.id}/room');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<String?> _askTargetChildId(String defaultChildId) async {
    final childOptions = _children.isNotEmpty
        ? _children
        : <ChildProfile>[
            ChildProfile(
              id: defaultChildId,
              name: 'Crianca atual',
              birthDate: DateTime(2018, 1, 1),
              favoriteThemes: const [],
              isArchived: false,
            ),
          ];
    String selected = defaultChildId;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Repetir aventura'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Crianca destino'),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Criar template'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _duplicateAsTemplate() async {
    final token = _accessToken();
    final detail = _detail;
    final sourceEpisode = _latestEpisode();
    if (token == null || detail == null || sourceEpisode == null) {
      return;
    }

    final targetChildId = await _askTargetChildId(detail.child.id);
    if (!mounted || targetChildId == null || targetChildId.isEmpty) {
      return;
    }

    setState(() => _working = true);
    try {
      final story = await ref
          .read(storyApiProvider)
          .duplicateStoryAsTemplate(
            token,
            sourceEpisode.storyId,
            childProfileId: targetChildId,
          );
      if (!mounted) {
        return;
      }
      context.push('/stories/${story.id}/room');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _working = false);
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
    final detail = _detail;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    if (_loading && detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhe da saga')),
        body: const Center(child: Text('Saga nao encontrada.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.title),
        actions: [
          IconButton(
            onPressed: _working ? null : _toggleFavorite,
            icon: Icon(
              detail.isFavorite ? Icons.star : Icons.star_border,
              color: detail.isFavorite ? Colors.amber.shade700 : null,
            ),
            tooltip: detail.isFavorite ? 'Desfavoritar' : 'Favoritar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: detail.title,
              subtitle: '${detail.child.name} · ${detail.theme}',
              assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroForest),
              showMascot: true,
              mascotPose: ViscondeMascotPose.readingBook,
              trailing: ViscondeAvatarBadge(
                imageAsset: ViscondeArtRegistry.resolve(
                  ViscondeArtKey.avatarChild,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ViscondeGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (detail.virtue != null)
                    Text('Virtude: ${detail.virtue!.name}'),
                  Text('Episodios: ${detail.episodes.length}'),
                  Text(
                    'Ultima referencia: ${dateFormat.format(detail.lastReferenceAt)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ViscondePrimaryCta(
                    onPressed: _working ? null : _continueAdventure,
                    icon: Icons.play_arrow,
                    label: 'Continuar aventura',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _duplicateAsTemplate,
                    icon: const Icon(Icons.copy),
                    label: const Text('Repetir aventura'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ViscondeSectionTitle(
              title: 'Capítulos',
              subtitle: 'Detalhes de cada episódio da saga',
            ),
            const SizedBox(height: 8),
            ...detail.episodes.map(
              (episode) => Card(
                child: ExpansionTile(
                  title: Text('Ep ${episode.episodeNumber} · ${episode.title}'),
                  subtitle: Text(
                    '${_statusLabel(episode.status)} · Atualizado em ${dateFormat.format(episode.updatedAt)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        context.push('/stories/${episode.storyId}/room'),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Personagens',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: episode.characters
                          .map(
                            (character) => Chip(
                              label: Text(
                                character.role == null ||
                                        character.role!.isEmpty
                                    ? character.name
                                    : '${character.name} (${character.role})',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Escolhas e narracao',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (episode.steps.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Sem etapas registradas.'),
                      ),
                    ...episode.steps.map(
                      (step) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(step.stepIndex.toString()),
                        ),
                        title: Text(
                          step.selectedOptionLabel ?? step.narratorText ?? '-',
                        ),
                        subtitle: Text(step.kind.name),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
