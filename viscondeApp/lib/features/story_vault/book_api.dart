import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'book_models.dart';

class BookApi {
  BookApi(this._dio);

  final Dio _dio;

  Future<BookProjectModel> createMonthlyBook(
    String childProfileId,
    String monthStr,
    String accessToken,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'books/monthly/$childProfileId',
      data: {'monthStr': monthStr},
      options: authOptions(accessToken),
    );

    return BookProjectModel.fromJson(response.data!);
  }

  Future<BookProjectModel> getBookProject(
    String bookId,
    String accessToken,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'books/$bookId',
      options: authOptions(accessToken),
    );

    return BookProjectModel.fromJson(response.data!);
  }
}
