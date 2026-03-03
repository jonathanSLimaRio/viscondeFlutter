import 'package:dio/dio.dart';

import '../core/network/api_exception.dart';

String _normalizeKnownMessage(ApiException error) {
  final message = error.message.trim();
  final normalized = message.toLowerCase();
  final code = error.code?.trim();

  if (code == 'PARENTAL_UNLOCK_REQUIRED') {
    return 'Área protegida por PIN. Desbloqueie a área adulta para continuar.';
  }

  if (code == 'PARENTAL_UNLOCK_INVALID') {
    return 'Seu desbloqueio da área adulta expirou. Digite o PIN novamente.';
  }

  if (error.kind == ApiErrorKind.unauthorized) {
    return 'Sua sessão expirou. Faça login novamente.';
  }

  if (error.kind == ApiErrorKind.parentalUnlock) {
    return 'Área protegida por PIN. Desbloqueie a área adulta para continuar.';
  }

  if (error.kind == ApiErrorKind.forbidden) {
    return 'Você não tem permissão para esta ação.';
  }

  if (error.kind == ApiErrorKind.network) {
    return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
  }

  if (error.kind == ApiErrorKind.timeout) {
    return 'A conexão demorou mais que o esperado. Tente novamente.';
  }

  if (normalized == 'unauthorized' || normalized == 'not authorized') {
    return 'Sua sessão expirou. Faça login novamente.';
  }

  if (normalized == 'forbidden') {
    return 'Você não tem permissão para esta ação.';
  }

  if (message.isEmpty) {
    return 'Erro inesperado.';
  }

  return message;
}

class ApiErrorPresentation {
  const ApiErrorPresentation({
    required this.message,
    this.sessionExpired = false,
    this.kind,
    this.statusCode,
    this.code,
  });

  final String message;
  final bool sessionExpired;
  final ApiErrorKind? kind;
  final int? statusCode;
  final String? code;
}

bool isSessionExpiredError(Object error) {
  if (error is ApiException) {
    return error.kind == ApiErrorKind.unauthorized;
  }

  if (error is DioException) {
    if (error.response?.statusCode == 401) {
      return true;
    }

    final rawMessage = error.message?.toLowerCase() ?? '';
    if (rawMessage.contains('unauthorized')) {
      return true;
    }
  }

  if (error is String) {
    final normalized = error.toLowerCase();
    if (normalized.contains('unauthorized') ||
        normalized.contains('não autorizado')) {
      return true;
    }
  }

  return false;
}

ApiErrorPresentation describeApiError(Object error) {
  if (error is ApiException) {
    final message = _normalizeKnownMessage(error);
    return ApiErrorPresentation(
      message: message,
      sessionExpired: error.kind == ApiErrorKind.unauthorized,
      kind: error.kind,
      statusCode: error.statusCode,
      code: error.code,
    );
  }

  if (error is DioException) {
    final nested = error.error;
    if (nested is ApiException) {
      return ApiErrorPresentation(
        message: _normalizeKnownMessage(nested),
        sessionExpired: nested.kind == ApiErrorKind.unauthorized,
        kind: nested.kind,
        statusCode: nested.statusCode,
        code: nested.code,
      );
    }

    final mapped = ApiException.fromDio(error);
    return ApiErrorPresentation(
      message: _normalizeKnownMessage(mapped),
      sessionExpired: mapped.kind == ApiErrorKind.unauthorized,
      kind: mapped.kind,
      statusCode: mapped.statusCode,
      code: mapped.code,
    );
  }

  if (error is String && error.trim().isNotEmpty) {
    if (isSessionExpiredError(error)) {
      return const ApiErrorPresentation(
        message: 'Sua sessão expirou. Faça login novamente.',
        sessionExpired: true,
        kind: ApiErrorKind.unauthorized,
        statusCode: 401,
      );
    }
    return ApiErrorPresentation(message: error.trim());
  }

  return const ApiErrorPresentation(message: 'Erro inesperado.');
}

String parseDioError(Object error) {
  return describeApiError(error).message;
}
