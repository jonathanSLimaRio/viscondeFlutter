import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/providers.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';
import '../../story_room/models/story_models.dart';
import '../story_vault_adventure_resolver.dart';

class StoryVaultCollectionRedirectScreen extends ConsumerStatefulWidget {
  const StoryVaultCollectionRedirectScreen({
    super.key,
    required this.collectionId,
  });

  final String collectionId;

  @override
  ConsumerState<StoryVaultCollectionRedirectScreen> createState() =>
      _StoryVaultCollectionRedirectScreenState();
}

class _StoryVaultCollectionRedirectScreenState
    extends ConsumerState<StoryVaultCollectionRedirectScreen> {
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectToStoryRoom();
    });
  }

  Future<void> _redirectToStoryRoom() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage =
            'Sua sessão expirou. Volte ao Baú e faça login novamente.';
      });
      return;
    }

    final storyApi = ref.read(storyApiProvider);
    StoryVaultCollectionItem? item;
    try {
      final collections = await storyApi.listStoryVaultCollections(token);
      for (final collection in collections) {
        if (collection.id == widget.collectionId) {
          item = collection;
          break;
        }
      }
    } catch (_) {
      item = null;
    }

    final resolver = StoryVaultAdventureResolver(storyApi);
    final result = await resolver.resolve(
      accessToken: token,
      collectionId: widget.collectionId,
      collectionItem: item,
    );

    if (!mounted) {
      return;
    }

    if (result.hasStoryTarget) {
      UxAnalytics.log(
        'vault_story_opened',
        params: <String, Object?>{
          'source': 'vault_legacy_route',
          'collection_id': widget.collectionId,
          'outcome': result.outcome == StoryVaultAdventureOutcome.draftOpened
              ? 'draft_opened'
              : 'continued_opened',
        },
      );
      context.go(AppRoute.storyRoom(result.storyId!));
      return;
    }

    UxAnalytics.log(
      'vault_story_open_failed',
      params: <String, Object?>{
        'source': 'vault_legacy_route',
        'collection_id': widget.collectionId,
        if (result.code != null && result.code!.trim().isNotEmpty)
          'code': result.code,
        if (result.message != null && result.message!.trim().isNotEmpty)
          'message': result.message,
      },
    );

    setState(() {
      _loading = false;
      _errorMessage =
          result.message ?? 'Não foi possível abrir esta aventura agora.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Abrindo aventura')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ViscondeContentState.error(
          title: 'Não foi possível abrir a história',
          description:
              _errorMessage ??
              'Tente novamente ou volte ao Baú para escolher outra saga.',
          primaryActionLabel: 'Tentar novamente',
          onPrimaryAction: () {
            setState(() {
              _loading = true;
              _errorMessage = null;
            });
            _redirectToStoryRoom();
          },
          secondaryActionLabel: 'Voltar ao Baú',
          onSecondaryAction: () => context.go(AppRoute.homePath()),
        ),
      ),
    );
  }
}
