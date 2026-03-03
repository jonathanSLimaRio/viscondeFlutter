import 'package:dio/dio.dart';

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  server,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Object? cause;

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final (message, code) = _extractMessageAndCode(error.response?.data);

    if (error.type == DioExceptionType.connectionError) {
      return ApiException(
        kind: ApiErrorKind.network,
        message: message ?? 'Falha de conexão com o servidor.',
        statusCode: status,
        code: code,
        cause: error,
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(
        kind: ApiErrorKind.timeout,
        message: message ?? 'Tempo limite de conexão excedido.',
        statusCode: status,
        code: code,
        cause: error,
      );
    }

    if (status == 401) {
      return ApiException(
        kind: ApiErrorKind.unauthorized,
        message: message ?? 'Sessão expirada. Faça login novamente.',
        statusCode: status,
        code: code,
        cause: error,
      );
    }

    if (status == 403) {
      return ApiException(
        kind: ApiErrorKind.forbidden,
        message: message ?? 'Você não tem permissão para esta ação.',
        statusCode: status,
        code: code,
        cause: error,
      );
    }

    if (status == 404) {
      return ApiException(
        kind: ApiErrorKind.notFound,
        message: message ?? 'Recurso não encontrado.',
        statusCode: status,
        code: code,
        cause: error,
      );
    }

    if (status == 409) {
      return ApiException(
        kind: ApiErrorKind.conflict,
        message: message ?? 'Conflito de estado. Atualize e tente novamente.',
        statusCode: status,
        code: code,
        cause: error,
      );
    }

    if (status == 422 || status == 400) {
      return ApiException(
        kind: ApiErrorKind.validation,
        message: message ?? 'Dados inválidos para esta operação.',
        statusCode: status,
        code: code,
        cause: error,
      );
    }

    if (status != null && status >= 500) {
      return ApiException(
        kind: ApiErrorKind.server,
        message: message ?? 'Falha interna no servidor.',
        statusCode: status,
        code: code,
        cause: error,
      );
    }

    return ApiException(
      kind: ApiErrorKind.unknown,
      message: message ?? 'Erro de requisição (${status ?? 'sem status'}).',
      statusCode: status,
      code: code,
      cause: error,
    );
  }

  static (String?, String?) _extractMessageAndCode(Object? raw) {
    if (raw is Map<String, dynamic>) {
      final errorMessage = raw['error'];
      final message = raw['message'];
      final code = raw['code'];

      final resolvedMessage = switch (true) {
        _ when errorMessage is String && errorMessage.trim().isNotEmpty =>
          errorMessage.trim(),
        _ when message is String && message.trim().isNotEmpty => message.trim(),
        _ => null,
      };

      return (
        resolvedMessage,
        code is String && code.trim().isNotEmpty ? code.trim() : null,
      );
    }

    return (null, null);
  }

  @override
  String toString() {
    return 'ApiException(kind: $kind, status: $statusCode, message: $message, code: $code)';
  }
}

Future<T> withApiException<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on ApiException {
    rethrow;
  } on DioException catch (error) {
    throw ApiException.fromDio(error);
  } catch (error) {
    throw ApiException(
      kind: ApiErrorKind.unknown,
      message: 'Falha ao processar resposta da API.',
      cause: error,
    );
  }
}
