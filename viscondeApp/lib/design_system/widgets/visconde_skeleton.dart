import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';
import 'visconde_glass_card.dart';

class ViscondeSkeletonBox extends StatefulWidget {
  const ViscondeSkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius,
    this.margin,
  });

  final double height;
  final double? width;
  final double? radius;
  final EdgeInsetsGeometry? margin;

  @override
  State<ViscondeSkeletonBox> createState() => _ViscondeSkeletonBoxState();
}

class _ViscondeSkeletonBoxState extends State<ViscondeSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    final radii = context.viscondeRadii;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final opacity = lerpDouble(0.28, 0.55, t);

        return Opacity(
          opacity: opacity ?? 0.4,
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: widget.margin,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius ?? radii.md),
              color: colors.parchmentSoft.withValues(alpha: 0.85),
            ),
          ),
        );
      },
    );
  }
}

class ViscondeSkeletonCard extends StatelessWidget {
  const ViscondeSkeletonCard({
    super.key,
    this.lines = 3,
    this.leading,
    this.trailing,
  });

  final int lines;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lineCount = math.max(1, lines);

    return ViscondeGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<Widget>.generate(lineCount, (index) {
                final isLast = index == lineCount - 1;
                return ViscondeSkeletonBox(
                  height: 12,
                  width: isLast ? 160 : null,
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                );
              }),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

double? lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) {
    return null;
  }

  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}
