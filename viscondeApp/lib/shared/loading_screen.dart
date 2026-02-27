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
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Text('Preparando sua aventura...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
