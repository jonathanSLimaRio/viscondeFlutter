import 'package:dio/dio.dart';

import '../core/network/api_client.dart';

class UxAnalyticsBatchClientInfo {
  const UxAnalyticsBatchClientInfo({
    this.platform,
    this.appVersion,
    this.appBuild,
    this.locale,
    this.timezone,
  });

  final String? platform;
  final String? appVersion;
  final String? appBuild;
  final String? locale;
  final String? timezone;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (platform != null && platform!.trim().isNotEmpty)
        'platform': platform!.trim(),
      if (appVersion != null && appVersion!.trim().isNotEmpty)
        'appVersion': appVersion!.trim(),
      if (appBuild != null && appBuild!.trim().isNotEmpty)
        'appBuild': appBuild!.trim(),
      if (locale != null && locale!.trim().isNotEmpty) 'locale': locale!.trim(),
      if (timezone != null && timezone!.trim().isNotEmpty)
        'timezone': timezone!.trim(),
    };
  }
}

class UxAnalyticsBatchEventPayload {
  const UxAnalyticsBatchEventPayload({
    required this.eventId,
    required this.name,
    required this.occurredAt,
    this.source,
    this.childId,
    this.params,
  });

  final String eventId;
  final String name;
  final DateTime occurredAt;
  final String? source;
  final String? childId;
  final Map<String, Object?>? params;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'eventId': eventId,
      'name': name,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      if (source != null && source!.trim().isNotEmpty) 'source': source!.trim(),
      if (childId != null && childId!.trim().isNotEmpty)
        'childId': childId!.trim(),
      if (params != null && params!.isNotEmpty) 'params': params,
    };
  }
}

class UxAnalyticsBatchPayload {
  const UxAnalyticsBatchPayload({
    required this.appSessionId,
    required this.events,
    this.client,
  });

  final String appSessionId;
  final List<UxAnalyticsBatchEventPayload> events;
  final UxAnalyticsBatchClientInfo? client;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'appSessionId': appSessionId,
      'events': events.map((event) => event.toJson()).toList(growable: false),
      if (client != null && client!.toJson().isNotEmpty)
        'client': client!.toJson(),
    };
  }
}

class UxAnalyticsBatchResult {
  const UxAnalyticsBatchResult({
    required this.accepted,
    required this.deduplicated,
    required this.rejected,
  });

  final int accepted;
  final int deduplicated;
  final int rejected;

  factory UxAnalyticsBatchResult.fromJson(Map<String, dynamic> json) {
    return UxAnalyticsBatchResult(
      accepted: (json['accepted'] as num?)?.toInt() ?? 0,
      deduplicated: (json['deduplicated'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract class UxAnalyticsTransport {
  Future<UxAnalyticsBatchResult> sendBatch(
    UxAnalyticsBatchPayload payload, {
    String? accessToken,
  });
}

class UxAnalyticsApi implements UxAnalyticsTransport {
  UxAnalyticsApi(this._dio);

  final Dio _dio;

  @override
  Future<UxAnalyticsBatchResult> sendBatch(
    UxAnalyticsBatchPayload payload, {
    String? accessToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'ux/events/batch',
      data: payload.toJson(),
      options: (accessToken == null || accessToken.trim().isEmpty)
          ? null
          : authOptions(accessToken.trim()),
    );

    return UxAnalyticsBatchResult.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}
