import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/expenses_summary.dart';

class ExpensesApi {
  ExpensesApi(this._client);
  final ApiClient _client;

  Future<ExpensesSummary> summary({DateTime? dateFrom, DateTime? dateTo}) async {
    try {
      final response = await _client.dio.get('/expenses/summary', queryParameters: {
        if (dateFrom != null) 'date_from': _dateOnly(dateFrom),
        if (dateTo != null) 'date_to': _dateOnly(dateTo),
      });
      return ExpensesSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
