import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';

class ViscondeScaffoldBackground extends StatelessWidget {
  const ViscondeScaffoldBackground({
    super.key,
    required this.child,
    this.safeArea = false,
    this.padding,
  });

  final Widget child;
  final bool safeArea;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;

    final content = Container(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.viscondeGradients.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.transparent,
                    colors.parchment.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -110,
            left: -90,
            child: _GlowBlob(
              color: colors.accent.withValues(alpha: 0.2),
              size: 320,
            ),
          ),
          Positioned(
            top: 120,
            right: -110,
            child: _GlowBlob(
              color: colors.secondary.withValues(alpha: 0.16),
              size: 260,
            ),
          ),
          Positioned(
            bottom: -140,
            right: -120,
            child: _GlowBlob(
              color: colors.secondary.withValues(alpha: 0.18),
              size: 340,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MagicDustPainter(
                  baseColor: colors.parchmentSoft.withValues(alpha: 0.7),
                  accentColor: colors.accent.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (safeArea) SafeArea(child: content) else content,
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.2),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: color.a * 0.6),
            blurRadius: size * 0.18,
            spreadRadius: size * 0.01,
          ),
        ],
      ),
    );
  }
}

class _MagicDustPainter extends CustomPainter {
  const _MagicDustPainter({required this.baseColor, required this.accentColor});

  final Color baseColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dustPaint = Paint()..style = PaintingStyle.fill;
    final rnd = math.Random(4207);

    for (var i = 0; i < 95; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final radius = 0.55 + rnd.nextDouble() * 1.7;

      final isAccent = i % 7 == 0;
      final opacity = isAccent
          ? 0.25 + rnd.nextDouble() * 0.22
          : 0.08 + rnd.nextDouble() * 0.18;
      dustPaint.color = (isAccent ? accentColor : baseColor).withValues(
        alpha: opacity,
      );

      canvas.drawCircle(Offset(x, y), radius, dustPaint);

      if (i % 11 == 0) {
        final linePaint = Paint()
          ..color = dustPaint.color.withValues(alpha: opacity * 0.7)
          ..strokeWidth = 0.9
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(x - 2, y), Offset(x + 2, y), linePaint);
        canvas.drawLine(Offset(x, y - 2), Offset(x, y + 2), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MagicDustPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.accentColor != accentColor;
  }
}
