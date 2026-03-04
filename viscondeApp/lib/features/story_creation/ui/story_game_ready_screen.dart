import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';
import '../../gamification/game_adventure_session_controller.dart';

class StoryGameReadyScreen extends ConsumerStatefulWidget {
  const StoryGameReadyScreen({
    super.key,
    required this.storyId,
    required this.title,
  });

  final String storyId;
  final String title;

  @override
  ConsumerState<StoryGameReadyScreen> createState() =>
      _StoryGameReadyScreenState();
}

class _StoryGameReadyScreenState extends ConsumerState<StoryGameReadyScreen> {
  static const int _initialSeconds = 3;

  Timer? _timer;
  int _remainingSeconds = _initialSeconds;
  bool _navigated = false;
  bool _resolvingStory = true;
  String? _resolvedTitle;

  String get _displayTitle {
    final resolved = _resolvedTitle?.trim();
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    return widget.title;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveStoryContext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resolveStoryContext() async {
    final storyId = widget.storyId.trim();
    if (storyId.isEmpty) {
      UxAnalytics.log(
        'story_game_ready_resolve_failed',
        params: const <String, Object?>{
          'source': 'story_game_ready_screen',
          'reason': 'missing_story_id',
        },
      );
      _finishResolving();
      return;
    }

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null || token.trim().isEmpty) {
      UxAnalytics.log(
        'story_game_ready_resolve_failed',
        params: <String, Object?>{
          'source': 'story_game_ready_screen',
          'story_id': storyId,
          'reason': 'missing_access_token',
        },
      );
      _finishResolving();
      return;
    }

    try {
      final session = await ref
          .read(storyApiProvider)
          .getStorySession(token, storyId);
      if (!mounted) {
        return;
      }

      final resolvedTitle = session.title.trim().isNotEmpty
          ? session.title.trim()
          : session.titleDraft.trim();

      ref
          .read(gameAdventureSessionControllerProvider.notifier)
          .setFromStory(
            storyId: session.id,
            title: resolvedTitle.isEmpty ? widget.title : resolvedTitle,
            childProfileId: session.childProfileId,
            theme: session.theme,
            biome: session.gameSummary?.biome ?? session.game?.map.biome,
          );

      UxAnalytics.log(
        'story_game_ready_resolved',
        params: <String, Object?>{
          'source': 'story_game_ready_screen',
          'story_id': session.id,
          'child_id': session.childProfileId,
        },
      );

      _finishResolving(
        resolvedTitle: resolvedTitle.isEmpty ? null : resolvedTitle,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      UxAnalytics.log(
        'story_game_ready_resolve_failed',
        params: <String, Object?>{
          'source': 'story_game_ready_screen',
          'story_id': storyId,
          'reason': 'story_session_fetch_failed',
          'message': parseDioError(error),
        },
      );
      _finishResolving();
    }
  }

  void _finishResolving({String? resolvedTitle}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _resolvingStory = false;
      _remainingSeconds = _initialSeconds;
      if (resolvedTitle != null && resolvedTitle.trim().isNotEmpty) {
        _resolvedTitle = resolvedTitle.trim();
      }
    });
    _startCountdown();
  }

  void _startCountdown() {
    if (_timer != null || _navigated || _resolvingStory) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _timer = null;
        _openGameHome();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  void _openGameHome() {
    if (!mounted || _navigated || _resolvingStory) {
      return;
    }
    _navigated = true;
    _timer?.cancel();
    _timer = null;
    context.go(AppRoute.homePath(tab: HomeTab.game));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ViscondeGlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 34,
                      color: colors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aventura pronta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _displayTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_resolvingStory) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preparando sua aventura...',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                    ),
                  ] else
                    Text(
                      'Entrando no Game em ${_remainingSeconds}s...',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ViscondePrimaryCta(
                      onPressed: _resolvingStory ? null : _openGameHome,
                      icon: Icons.play_arrow_rounded,
                      label: _resolvingStory
                          ? 'Preparando...'
                          : 'Começar agora',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
