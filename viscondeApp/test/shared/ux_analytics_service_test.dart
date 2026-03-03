import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

class _MemoryUxStore implements UxAnalyticsStore {
  final List<QueuedUxAnalyticsEvent> _items = <QueuedUxAnalyticsEvent>[];
  int _nextId = 1;

  @override
  Future<void> enqueue({
    required UxAnalyticsEvent event,
    required String appSessionId,
    String? source,
    String? childId,
    Map<String, Object?> params = const <String, Object?>{},
  }) async {
    final now = DateTime.now();
    _items.add(
      QueuedUxAnalyticsEvent(
        id: _nextId++,
        eventId: event.eventId,
        name: event.name,
        appSessionId: appSessionId,
        occurredAt: event.occurredAt,
        params: params,
        source: source,
        childId: childId,
        status: UxAnalyticsQueueStatus.pending,
        retryCount: 0,
        nextRetryAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<QueuedUxAnalyticsEvent>> listRetryable({int limit = 50}) async {
    final now = DateTime.now();
    return _items
        .where(
          (item) =>
              item.status == UxAnalyticsQueueStatus.pending ||
              (item.status == UxAnalyticsQueueStatus.failed &&
                  (item.nextRetryAt == null ||
                      !item.nextRetryAt!.isAfter(now))),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<void> markFailed(List<int> ids, {String? reason}) async {
    for (final id in ids) {
      final index = _items.indexWhere((item) => item.id == id);
      if (index < 0) {
        continue;
      }
      final current = _items[index];
      _items[index] = QueuedUxAnalyticsEvent(
        id: current.id,
        eventId: current.eventId,
        name: current.name,
        appSessionId: current.appSessionId,
        occurredAt: current.occurredAt,
        params: current.params,
        source: current.source,
        childId: current.childId,
        status: UxAnalyticsQueueStatus.failed,
        retryCount: current.retryCount + 1,
        nextRetryAt: DateTime.now().subtract(const Duration(seconds: 1)),
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> markSent(List<int> ids) async {
    for (final id in ids) {
      final index = _items.indexWhere((item) => item.id == id);
      if (index < 0) {
        continue;
      }
      final current = _items[index];
      _items[index] = QueuedUxAnalyticsEvent(
        id: current.id,
        eventId: current.eventId,
        name: current.name,
        appSessionId: current.appSessionId,
        occurredAt: current.occurredAt,
        params: current.params,
        source: current.source,
        childId: current.childId,
        status: UxAnalyticsQueueStatus.sent,
        retryCount: current.retryCount,
        nextRetryAt: null,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  int countByStatus(UxAnalyticsQueueStatus status) {
    return _items.where((item) => item.status == status).length;
  }

  List<QueuedUxAnalyticsEvent> get all =>
      List<QueuedUxAnalyticsEvent>.from(_items);

  @override
  Future<void> dispose() async {}
}

class _FakeUxTransport implements UxAnalyticsTransport {
  int sendCalls = 0;
  bool shouldThrow = false;
  Duration delay = Duration.zero;
  UxAnalyticsBatchPayload? lastPayload;

  @override
  Future<UxAnalyticsBatchResult> sendBatch(
    UxAnalyticsBatchPayload payload, {
    String? accessToken,
  }) async {
    sendCalls += 1;
    lastPayload = payload;

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (shouldThrow) {
      throw Exception('network');
    }

    return UxAnalyticsBatchResult(
      accepted: payload.events.length,
      deduplicated: 0,
      rejected: 0,
    );
  }
}

UxAnalyticsEvent _event(
  String name, {
  Map<String, Object?> params = const <String, Object?>{},
}) {
  return UxAnalyticsEvent(
    eventId: 'evt-${DateTime.now().microsecondsSinceEpoch}',
    name: name,
    occurredAt: DateTime.now().toUtc(),
    params: params,
  );
}

void main() {
  group('UxAnalyticsService', () {
    test('enqueue + flush success', () async {
      final store = _MemoryUxStore();
      final transport = _FakeUxTransport();
      final service = UxAnalyticsService(
        store: store,
        transport: transport,
        readAccessToken: () => 'token-123',
        appSessionId: 'app-test-1',
      );

      await service.trackEvent(
        _event(
          'story_create_step_completed',
          params: <String, Object?>{
            'step': 1,
            'child_id': 'child-1',
            'source': 'create_story_screen',
          },
        ),
      );

      await service.flush();

      expect(transport.sendCalls, 1);
      expect(store.countByStatus(UxAnalyticsQueueStatus.sent), 1);
      final sentEvent = transport.lastPayload!.events.single;
      expect(sentEvent.name, 'story_create_step_completed');
      expect(sentEvent.childId, 'child-1');
      expect(sentEvent.source, 'create_story_screen');
      expect(sentEvent.params?['step'], 1);
      expect(sentEvent.params?['source'], isNull);
      expect(sentEvent.params?['child_id'], isNull);
    });

    test('flush failure keeps event retryable', () async {
      final store = _MemoryUxStore();
      final transport = _FakeUxTransport()..shouldThrow = true;
      final service = UxAnalyticsService(
        store: store,
        transport: transport,
        readAccessToken: () => null,
        appSessionId: 'app-test-2',
      );

      await service.trackEvent(_event('story_create_started'));
      await service.flush();

      expect(transport.sendCalls, 1);
      expect(store.countByStatus(UxAnalyticsQueueStatus.failed), 1);

      transport.shouldThrow = false;
      await service.flush();

      expect(transport.sendCalls, 2);
      expect(store.countByStatus(UxAnalyticsQueueStatus.sent), 1);
    });

    test('flush is single-flight with concurrent callers', () async {
      final store = _MemoryUxStore();
      final transport = _FakeUxTransport()
        ..delay = const Duration(milliseconds: 80);
      final service = UxAnalyticsService(
        store: store,
        transport: transport,
        readAccessToken: () => 'token-xyz',
        appSessionId: 'app-test-3',
      );

      await service.trackEvent(_event('game_hub_opened'));
      await Future.wait([service.flush(), service.flush()]);

      expect(transport.sendCalls, 1);
      expect(store.countByStatus(UxAnalyticsQueueStatus.sent), 1);
    });

    test('unsupported event name is ignored', () async {
      final store = _MemoryUxStore();
      final transport = _FakeUxTransport();
      final service = UxAnalyticsService(
        store: store,
        transport: transport,
        readAccessToken: () => null,
        appSessionId: 'app-test-4',
      );

      await service.trackEvent(_event('reward_modal_opened'));
      await service.flush();

      expect(store.all, isEmpty);
      expect(transport.sendCalls, 0);
    });
  });
}
