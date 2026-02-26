import 'package:dio/dio.dart';

String parseDioError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Falha de conexao com o servidor.';
    }

    return 'Erro de requisicao (${error.response?.statusCode ?? 'sem status'}).';
  }

  return 'Erro inesperado.';
}
