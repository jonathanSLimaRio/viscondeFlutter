import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/visconde.dart';

class StoryRoomHeader extends StatefulWidget {
  const StoryRoomHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.xp,
    required this.maxXp,
    required this.backgroundImageAsset,
    this.parentAvatarUrl,
    this.childAvatarUrl,
    this.trailingAction,
    this.xpAnimationNonce = 0,
  });

  final int currentStep;
  final int totalSteps;
  final int xp;
  final int maxXp;
  final String backgroundImageAsset;
  final String? parentAvatarUrl;
  final String? childAvatarUrl;
  final Widget? trailingAction;
  final int xpAnimationNonce;

  @override
  State<StoryRoomHeader> createState() => _StoryRoomHeaderState();
}

class _StoryRoomHeaderState extends State<StoryRoomHeader>
    with TickerProviderStateMixin {
  static const double _avatarSize = 54;
  static const List<Offset> _avatarTrail = <Offset>[
    Offset(0.12, 0.74),
    Offset(0.20, 0.70),
    Offset(0.29, 0.67),
    Offset(0.37, 0.63),
    Offset(0.45, 0.59),
    Offset(0.53, 0.56),
    Offset(0.61, 0.52),
    Offset(0.69, 0.50),
    Offset(0.76, 0.47),
    Offset(0.83, 0.44),
    Offset(0.88, 0.40),
    Offset(0.92, 0.36),
  ];
  static const Offset _parentOffset = Offset(-0.045, 0.015);
  static const Offset _childOffset = Offset(0.035, -0.010);

  late final AnimationController _trophyController;
  late final AnimationController _xpPulseController;
  bool _showTrophy = false;

  @override
  void initState() {
    super.initState();
    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _xpPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void didUpdateWidget(covariant StoryRoomHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.xpAnimationNonce != oldWidget.xpAnimationNonce) {
      _playTrophyAnimation();
      _playXpPulseAnimation();
    }
  }

  void _playXpPulseAnimation() {
    _xpPulseController.forward(from: 0);
  }

  Future<void> _playTrophyAnimation() async {
    if (!_showTrophy && mounted) {
      setState(() => _showTrophy = true);
    }
    _trophyController.stop();
    _trophyController.value = 0;
    await _trophyController.forward();
    if (!mounted) {
      return;
    }
    await _trophyController.reverse();
    if (!mounted) {
      return;
    }
    setState(() => _showTrophy = false);
  }

  @override
  void dispose() {
    _trophyController.dispose();
    _xpPulseController.dispose();
    super.dispose();
  }

  Offset _trailPointForStep(int step) {
    final clamped = step.clamp(1, _avatarTrail.length).toInt();
    return _avatarTrail[clamped - 1];
  }

  Offset _normalizePoint(Offset value) {
    return Offset(
      value.dx.clamp(0.0, 1.0).toDouble(),
      value.dy.clamp(0.0, 1.0).toDouble(),
    );
  }

  double _positionLeft(Offset normalized, double width) {
    final raw = (normalized.dx * width) - (_avatarSize / 2);
    final maxLeft = math.max(0, width - _avatarSize);
    return raw.clamp(0.0, maxLeft).toDouble();
  }

  double _positionTop(Offset normalized, double height) {
    final raw = (normalized.dy * height) - (_avatarSize / 2);
    final maxTop = math.max(0, height - _avatarSize);
    return raw.clamp(0.0, maxTop).toDouble();
  }

  Widget _buildTrophyAnimation() {
    if (!_showTrophy) {
      return const SizedBox(width: 20, height: 20);
    }
    return AnimatedBuilder(
      animation: _trophyController,
      builder: (context, child) {
        final value = _trophyController.value;
        if (value <= 0.01) {
          return const SizedBox(width: 20, height: 20);
        }

        final scale = 0.78 + (Curves.easeOutBack.transform(value) * 0.36);
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: const Icon(
        Icons.emoji_events_rounded,
        key: ValueKey<String>('story_room_xp_trophy'),
        color: Color(0xFFFFC107),
        size: 20,
      ),
    );
  }

  Widget _buildStageAvatar({
    required String fallbackAsset,
    required String keyValue,
    String? imageUrl,
  }) {
    final normalizedUrl = imageUrl?.trim();
    final hasNetwork = normalizedUrl != null && normalizedUrl.isNotEmpty;

    return Container(
      key: ValueKey<String>(keyValue),
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: hasNetwork
            ? Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Image.asset(fallbackAsset, fit: BoxFit.cover),
              )
            : Image.asset(fallbackAsset, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildShieldSwordIcon() {
    return const SizedBox(
      key: ValueKey<String>('story_room_xp_shield_sword'),
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Icon(LucideIcons.shield, size: 21, color: Color(0xFFB8860B)),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Icon(LucideIcons.sword, size: 12, color: Color(0xFF6D4C41)),
          ),
        ],
      ),
    );
  }

  Widget _buildXpCluster() {
    return AnimatedBuilder(
      animation: _xpPulseController,
      builder: (context, child) {
        final pulse = math.sin(_xpPulseController.value * math.pi);
        final scale = 1 + (pulse * 0.06);
        final opacity = 0.92 + (pulse * 0.08);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.centerLeft,
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildShieldSwordIcon(),
          const SizedBox(width: 8),
          Text(
            'XP  ${widget.xp} / ${widget.maxXp}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          _buildTrophyAnimation(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radii = context.viscondeRadii;
    final boundedStep = widget.currentStep.clamp(0, widget.totalSteps).toInt();
    final progress = widget.totalSteps <= 0
        ? 0.0
        : (boundedStep / widget.totalSteps).clamp(0.0, 1.0);

    final basePoint = _trailPointForStep(widget.currentStep);
    final parentPoint = _normalizePoint(basePoint + _parentOffset);
    final childPoint = _normalizePoint(basePoint + _childOffset);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radii.md),
                topRight: Radius.circular(radii.md),
              ),
              child: SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        widget.backgroundImageAsset,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 340),
                                curve: Curves.easeOutCubic,
                                left: _positionLeft(
                                  parentPoint,
                                  constraints.maxWidth,
                                ),
                                top: _positionTop(
                                  parentPoint,
                                  constraints.maxHeight,
                                ),
                                child: _buildStageAvatar(
                                  keyValue: 'story_room_parent_avatar',
                                  imageUrl: widget.parentAvatarUrl,
                                  fallbackAsset: ViscondeArtRegistry.resolve(
                                    ViscondeArtKey.avatarParent,
                                  ),
                                ),
                              ),
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 340),
                                curve: Curves.easeOutCubic,
                                left: _positionLeft(
                                  childPoint,
                                  constraints.maxWidth,
                                ),
                                top: _positionTop(
                                  childPoint,
                                  constraints.maxHeight,
                                ),
                                child: _buildStageAvatar(
                                  keyValue: 'story_room_child_avatar',
                                  imageUrl: widget.childAvatarUrl,
                                  fallbackAsset: ViscondeArtRegistry.resolve(
                                    ViscondeArtKey.avatarChild,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: Container(
                        key: const ValueKey<String>('story_room_scene_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F5B6F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Cena ${widget.currentStep}/${widget.totalSteps}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF1F5B6F),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(radii.md),
              bottomRight: Radius.circular(radii.md),
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(radii.md),
                    bottomRight: progress >= 1
                        ? Radius.circular(radii.md)
                        : Radius.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _buildXpCluster(),
              const Spacer(),
              if (widget.trailingAction != null) widget.trailingAction!,
            ],
          ),
        ),
      ],
    );
  }
}
