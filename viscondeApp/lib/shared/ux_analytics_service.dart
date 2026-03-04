import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'logging/app_logger.dart';
import 'ux_analytics.dart';
import 'ux_analytics_api.dart';
import 'ux_analytics_queue.dart';

typedef AccessTokenReader = String? Function();

class UxAnalyticsService {
  UxAnalyticsService({
    required UxAnalyticsStore store,
    required UxAnalyticsTransport transport,
    required AccessTokenReader readAccessToken,
    String? appSessionId,
  }) : _store = store,
       _transport = transport,
       _readAccessToken = readAccessToken,
       _appSessionId = appSessionId ?? _buildAppSessionId();

  final UxAnalyticsStore _store;
  final UxAnalyticsTransport _transport;
  final AccessTokenReader _readAccessToken;
  final String _appSessionId;
  static const Set<String> supportedEventNames = <String>{
    'session_started',
    'auth_error_shown',
    'auth_refresh_success',
    'auth_refresh_failed',
    'story_create_started',
    'story_create_step_completed',
    'story_create_abandoned',
    'story_published',
    'game_hub_opened',
    'vault_state_shown',
    'vault_retry_tapped',
    'vault_empty_cta_tapped',
    'game_state_shown',
    'game_retry_tapped',
    'game_empty_cta_tapped',
    'post_publish_modal_opened',
    'post_publish_cta_clicked',
    'pin_prompt_shown',
    'pin_prompt_success',
    'pin_prompt_abandon',
    'pin_lock_now_clicked',
    'vault_story_opened',
    'vault_story_open_failed',
    'vault_collection_actions_opened',
  };

  bool _started = false;
  bool _disposed = false;
  Future<void>? _flushInFlight;

  String get appSessionId => _appSessionId;

  void ensureStarted() {
    if (_started || _disposed) {
      return;
    }

    _started = true;
    UxAnalytics.log(
      'session_started',
      params: const <String, Object?>{'source': 'app_boot'},
    );
    unawaited(flush());
  }

  Future<void> trackEvent(UxAnalyticsEvent event) async {
    if (_disposed) {
      return;
    }

    if (!supportedEventNames.contains(event.name)) {
      return;
    }

    final source = _readString(event.params['source']);
    final childId = _readString(event.params['child_id']);
    final sanitizedParams = _sanitizeParams(event.params);

    await _store.enqueue(
      event: event,
      appSessionId: _appSessionId,
      source: source,
      childId: childId,
      params: sanitizedParams,
    );

    unawaited(flush());
  }

  Future<void> flush() {
    final inFlight = _flushInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final next = _flushLoop();
    _flushInFlight = next;
    next.whenComplete(() {
      if (identical(_flushInFlight, next)) {
        _flushInFlight = null;
      }
    });
    return next;
  }

  Future<void> _flushLoop() async {
    if (_disposed) {
      return;
    }

    while (!_disposed) {
      final batch = await _store.listRetryable(limit: 50);
      if (batch.isEmpty) {
        return;
      }

      final payload = UxAnalyticsBatchPayload(
        appSessionId: _appSessionId,
        client: _buildClientInfo(),
        events: batch
            .map(
              (event) => UxAnalyticsBatchEventPayload(
                eventId: event.eventId,
                name: event.name,
                occurredAt: event.occurredAt,
                source: event.source,
                childId: event.childId,
                params: event.params,
              ),
            )
            .toList(growable: false),
      );

      try {
        await _transport.sendBatch(payload, accessToken: _readAccessToken());
        await _store.markSent(batch.map((event) => event.id).toList());
      } catch (error) {
        await _store.markFailed(
          batch.map((event) => event.id).toList(),
          reason: error.toString(),
        );
        return;
      }
    }
  }

  UxAnalyticsBatchClientInfo _buildClientInfo() {
    return UxAnalyticsBatchClientInfo(
      platform: _platformName(),
      locale: _localeTag(),
      timezone: DateTime.now().timeZoneName,
    );
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String? _localeTag() {
    try {
      return WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao obter locale para analytics.',
        error: error,
        stackTrace: stackTrace,
        scope: 'analytics',
      );
      return null;
    }
  }

  Map<String, Object?> _sanitizeParams(Map<String, Object?> rawParams) {
    final cleaned = <String, Object?>{};

    for (final entry in rawParams.entries) {
      if (entry.key == 'source' || entry.key == 'child_id') {
        continue;
      }

      final value = entry.value;
      if (value is String || value is num || value is bool || value == null) {
        cleaned[entry.key] = value;
      }
    }

    return cleaned;
  }

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _store.dispose();
  }

  static String _buildAppSessionId() {
    final random = Random().nextInt(1 << 30);
    return 'app-${DateTime.now().microsecondsSinceEpoch}-$random';
  }
}
