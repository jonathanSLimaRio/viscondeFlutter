import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/visconde.dart';
import 'router.dart';
import '../shared/providers.dart';
import '../shared/ux_analytics.dart';

class ViscondeApp extends ConsumerStatefulWidget {
  const ViscondeApp({super.key});

  @override
  ConsumerState<ViscondeApp> createState() => _ViscondeAppState();
}

class _ViscondeAppState extends ConsumerState<ViscondeApp> {
  @override
  void initState() {
    super.initState();
    final analytics = ref.read(uxAnalyticsServiceProvider);
    UxAnalytics.configure(sink: analytics.trackEvent);
    analytics.ensureStarted();
  }

  @override
  void dispose() {
    UxAnalytics.clearSink();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

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
