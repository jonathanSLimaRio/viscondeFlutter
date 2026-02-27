import 'package:flutter/material.dart';

import '../art/visconde_art_registry.dart';
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
          Opacity(
            opacity: 0.06,
            child: Image.asset(
              ViscondeArtRegistry.resolve(ViscondeArtKey.paperTexture),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            child: _GlowBlob(
              color: colors.accent.withValues(alpha: 0.2),
              size: 260,
            ),
          ),
          Positioned(
            bottom: -120,
            right: -90,
            child: _GlowBlob(
              color: colors.secondary.withValues(alpha: 0.18),
              size: 300,
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
      ),
    );
  }
}
