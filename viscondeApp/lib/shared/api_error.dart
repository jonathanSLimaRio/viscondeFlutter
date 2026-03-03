import 'package:dio/dio.dart';

import '../core/network/api_exception.dart';

String parseDioError(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  if (error is DioException) {
    final nested = error.error;
    if (nested is ApiException) {
      return nested.message;
    }

    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Falha de conexão com o servidor.';
    }

    return 'Erro de requisição (${error.response?.statusCode ?? 'sem status'}).';
  }

  if (error is String && error.trim().isNotEmpty) {
    return error.trim();
  }

  return 'Erro inesperado.';
}
