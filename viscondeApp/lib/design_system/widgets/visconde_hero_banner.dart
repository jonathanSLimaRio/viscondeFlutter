// ignore_for_file: deprecated_member_use, use_null_aware_elements

import 'package:flutter/material.dart';

import '../tokens/visconde_tokens.dart';
import 'visconde_glass_card.dart';

class ViscondeHeroBanner extends StatelessWidget {
  const ViscondeHeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.assetPath,
    this.trailing,
    this.height = 170,
  });

  final String title;
  final String? subtitle;
  final String? assetPath;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    return ViscondeGlassCard(
      padding: EdgeInsets.zero,
      radius: context.viscondeRadii.xl,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (assetPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(context.viscondeRadii.xl),
                child: Image.asset(assetPath!, fit: BoxFit.cover),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.viscondeRadii.xl),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    colors.parchment.withOpacity(0.82),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
