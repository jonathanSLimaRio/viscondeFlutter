import 'package:flutter/foundation.dart';

class UxAnalytics {
  const UxAnalytics._();

  static void log(
    String event, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    if (kDebugMode) {
      final payload = params.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      debugPrint(
        payload.isEmpty ? '[ux-event] $event' : '[ux-event] $event | $payload',
      );
    }
  }
}
