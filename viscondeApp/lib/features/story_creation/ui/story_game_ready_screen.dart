import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';

class StoryGameReadyScreen extends StatefulWidget {
  const StoryGameReadyScreen({
    super.key,
    required this.storyId,
    required this.title,
  });

  final String storyId;
  final String title;

  @override
  State<StoryGameReadyScreen> createState() => _StoryGameReadyScreenState();
}

class _StoryGameReadyScreenState extends State<StoryGameReadyScreen> {
  static const int _initialSeconds = 3;

  Timer? _timer;
  int _remainingSeconds = _initialSeconds;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _openGameHome();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openGameHome() {
    if (!mounted || _navigated) {
      return;
    }
    _navigated = true;
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
                    widget.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
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
                      onPressed: _openGameHome,
                      icon: Icons.play_arrow_rounded,
                      label: 'Começar agora',
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
