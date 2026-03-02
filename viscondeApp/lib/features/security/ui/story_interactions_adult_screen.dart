import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../../story_room/models/story_models.dart';
import '../parental_gate_controller.dart';

class StoryInteractionsAdultScreen extends ConsumerStatefulWidget {
  const StoryInteractionsAdultScreen({super.key});

  @override
  ConsumerState<StoryInteractionsAdultScreen> createState() =>
      _StoryInteractionsAdultScreenState();
}

class _StoryInteractionsAdultScreenState
    extends ConsumerState<StoryInteractionsAdultScreen> {
  List<StoryListItem> _stories = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStories();
    });
  }

  Future<void> _loadStories() async {
    final token = ref.read(authControllerProvider).accessToken;
    final gate = ref.read(parentalGateControllerProvider);

    if (token == null || !gate.isUnlocked || gate.unlockToken == null) {
      return;
    }

    setState(() => _loading = true);

    try {
      final stories = await ref.read(storyApiProvider).listStories(token);
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

  Future<void> _openInteractions(StoryListItem story) async {
    final token = ref.read(authControllerProvider).accessToken;
    final gate = ref.read(parentalGateControllerProvider);

    if (token == null || !gate.isUnlocked || gate.unlockToken == null) {
      return;
    }

    try {
      final result = await ref
          .read(storyApiProvider)
          .getStoryInteractions(
            token,
            story.id,
            parentalUnlockToken: gate.unlockToken!,
          );

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Text(
                    result.storyTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Interacoes: ${result.interactions.length}'),
                  const SizedBox(height: 12),
                  ...result.interactions.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.authorDisplayName),
                        subtitle: Text(item.messageText ?? item.emoji ?? '-'),
                        trailing: Text(item.type),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (parseDioError(error).contains('desbloqueio')) {
        ref.read(parentalGateControllerProvider.notifier).clear();
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(parentalGateControllerProvider);

    if (!gate.isUnlocked || gate.unlockToken == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Interacoes remotas')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ViscondeGlassCard(
              child: ViscondeSectionTitle(
                title: 'Área protegida',
                subtitle:
                    'Volte para a área adulta, faça desbloqueio por PIN e tente novamente.',
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Interacoes remotas')),
      body: RefreshIndicator(
        onRefresh: _loadStories,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'Interações da Sala',
              subtitle: 'Histórico de chat e reações do modo remoto.',
              assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroSpace),
              showMascot: true,
              mascotPose: ViscondeMascotPose.seriousController,
              trailing: ViscondeAvatarBadge(
                imageAsset: ViscondeArtRegistry.resolve(
                  ViscondeArtKey.avatarParent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loading && _stories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Nenhuma historia encontrada.'),
              ),
            ..._stories.map(
              (story) => ViscondeGlassCard(
                child: ListTile(
                  title: Text(story.title),
                  subtitle: Text(
                    '${story.childName} · ${story.sessionKind.name.toUpperCase()}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openInteractions(story),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
