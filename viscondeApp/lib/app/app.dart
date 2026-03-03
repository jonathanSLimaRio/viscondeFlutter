import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/visconde.dart';
import 'router.dart';
import '../shared/providers.dart';
import '../shared/ux_analytics.dart';

class ViscondeApp extends ConsumerWidget {
  const ViscondeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final analytics = ref.watch(uxAnalyticsServiceProvider);

    UxAnalytics.configure(sink: analytics.trackEvent);
    analytics.ensureStarted();

    return MaterialApp.router(
      title: 'Visconde App',
      debugShowCheckedModeBanner: false,
      theme: ViscondeTheme.buildLightTheme(),
      builder: (context, child) {
        return ViscondeScaffoldBackground(
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
