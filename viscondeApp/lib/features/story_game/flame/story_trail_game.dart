import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../story_room/models/story_models.dart';

enum StoryTrailNodeStatus { locked, current, completed, pending }

class StoryTrailNodeSnapshot {
  const StoryTrailNodeSnapshot({required this.node, required this.status});

  final StoryGameNodeModel node;
  final StoryTrailNodeStatus status;
}

class TrailMapComponent extends PositionComponent {
  TrailMapComponent({required this.points});

  final List<Vector2> points;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (points.length < 2) {
      return;
    }

    final paint = Paint()
      ..color = const Color(0x665A6E7F)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }

    canvas.drawPath(path, paint);
  }
}

class NodeComponent extends PositionComponent {
  NodeComponent({
    required this.index,
    required this.status,
    required Vector2 center,
  }) : super(position: center, size: Vector2.all(30), anchor: Anchor.center);

  final int index;
  final StoryTrailNodeStatus status;

  Color _statusColor() {
    switch (status) {
      case StoryTrailNodeStatus.completed:
        return const Color(0xFF2E7D32);
      case StoryTrailNodeStatus.current:
        return const Color(0xFF1976D2);
      case StoryTrailNodeStatus.pending:
        return const Color(0xFFF9A825);
      case StoryTrailNodeStatus.locked:
        return const Color(0xFF90A4AE);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(
      CircleComponent(
        radius: size.x / 2,
        paint: Paint()..color = _statusColor(),
        anchor: Anchor.center,
        position: size / 2,
      ),
    );

    add(
      TextComponent(
        text: index.toString(),
        anchor: Anchor.center,
        position: size / 2,
        textRenderer: TextPaint(
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class AvatarComponent extends CircleComponent {
  AvatarComponent({required Vector2 center})
    : super(
        radius: 12,
        anchor: Anchor.center,
        position: center,
        paint: Paint()..color = const Color(0xFF8E24AA),
      );
}

class StoryTrailGame extends FlameGame {
  StoryTrailGame();

  List<StoryTrailNodeSnapshot> _snapshots = const <StoryTrailNodeSnapshot>[];
  int _currentNodeIndex = 1;

  AvatarComponent? _avatar;

  Vector2 _toWorld(StoryGameNodeModel node) {
    final width = size.x <= 0 ? 320 : size.x;
    final height = size.y <= 0 ? 220 : size.y;
    final x = 18 + node.x * (width - 36);
    final y = 18 + node.y * (height - 36);
    return Vector2(x, y);
  }

  Vector2 _currentNodePosition() {
    final current = _snapshots.firstWhere(
      (snapshot) => snapshot.node.index == _currentNodeIndex,
      orElse: () => _snapshots.isNotEmpty
          ? _snapshots.first
          : StoryTrailNodeSnapshot(
              node: const StoryGameNodeModel(
                index: 1,
                x: 0.1,
                y: 0.5,
                kind: 'START',
              ),
              status: StoryTrailNodeStatus.current,
            ),
    );

    return _toWorld(current.node);
  }

  void setSnapshots(
    List<StoryTrailNodeSnapshot> snapshots, {
    required int currentNodeIndex,
    bool animateAvatar = true,
  }) {
    _snapshots = snapshots;
    _currentNodeIndex = currentNodeIndex;
    _rebuildWorld(animateAvatar: animateAvatar);
  }

  void _rebuildWorld({required bool animateAvatar}) {
    if (!isMounted || _snapshots.isEmpty) {
      return;
    }

    children.whereType<TrailMapComponent>().toList().forEach(remove);
    children.whereType<NodeComponent>().toList().forEach(remove);

    final points = _snapshots
        .map((snapshot) => _toWorld(snapshot.node))
        .toList();
    add(TrailMapComponent(points: points));

    for (final snapshot in _snapshots) {
      add(
        NodeComponent(
          index: snapshot.node.index,
          status: snapshot.status,
          center: _toWorld(snapshot.node),
        ),
      );
    }

    final target = _currentNodePosition();
    if (_avatar == null) {
      _avatar = AvatarComponent(center: target);
      add(_avatar!);
      return;
    }

    _avatar!.removeWhere((component) => component is MoveToEffect);
    if (!animateAvatar) {
      _avatar!.position = target;
      return;
    }

    _avatar!.add(
      MoveToEffect(
        target,
        EffectController(duration: 0.45, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _rebuildWorld(animateAvatar: false);
  }
}
