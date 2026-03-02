import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef DioRequestHandler =
    Future<ResponseBody> Function(RequestOptions options);

class FakeDioAdapter implements HttpClientAdapter {
  FakeDioAdapter(this.handler);

  final DioRequestHandler handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }
}

ResponseBody jsonResponse(
  Object? data, {
  int statusCode = 200,
  Map<String, List<String>> headers = const <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: headers,
  );
}
