import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'logging/app_logger.dart';

class UxAnalyticsEvent {
  const UxAnalyticsEvent({
    required this.eventId,
    required this.name,
    required this.occurredAt,
    required this.params,
  });

  final String eventId;
  final String name;
  final DateTime occurredAt;
  final Map<String, Object?> params;
}

typedef UxAnalyticsSink = FutureOr<void> Function(UxAnalyticsEvent event);

class UxAnalytics {
  const UxAnalytics._();

  static final Random _random = Random();
  static UxAnalyticsSink? _sink;
  static int _sequence = 0;

  static void configure({UxAnalyticsSink? sink}) {
    _sink = sink;
  }

  static void clearSink() {
    _sink = null;
  }

  static void log(
    String event, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final uxEvent = UxAnalyticsEvent(
      eventId: _nextEventId(),
      name: event,
      occurredAt: DateTime.now().toUtc(),
      params: Map<String, Object?>.from(params),
    );

    final sink = _sink;
    if (sink != null) {
      try {
        final result = sink(uxEvent);
        if (result is Future<void>) {
          unawaited(
            result.catchError((error, stackTrace) {
              AppLogger.warn(
                'Falha assíncrona ao enviar evento de analytics.',
                error: error,
                stackTrace: stackTrace,
                scope: 'analytics',
              );
            }),
          );
        }
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Falha síncrona ao processar evento de analytics.',
          error: error,
          stackTrace: stackTrace,
          scope: 'analytics',
        );
        // Never block product flows because of analytics.
      }
    }

    if (kDebugMode) {
      final payload = uxEvent.params.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      debugPrint(
        payload.isEmpty
            ? '[ux-event] ${uxEvent.name}'
            : '[ux-event] ${uxEvent.name} | $payload',
      );
    }
  }

  static String _nextEventId() {
    _sequence += 1;
    final randomChunk = _random.nextInt(1 << 20);
    return 'evt-${DateTime.now().microsecondsSinceEpoch}-${_sequence}_$randomChunk';
  }
}
