import 'package:flutter/material.dart';

import '../design_system/visconde.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ViscondeGlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  ViscondeArtRegistry.resolve(ViscondeArtKey.logoVisconde),
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const ViscondeMascot(
                  pose: ViscondeMascotPose.wavingControllerBook,
                  size: 88,
                  glow: true,
                  opacity: 0.92,
                ),
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        'Preparando sua aventura...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
