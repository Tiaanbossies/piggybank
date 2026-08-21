import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/transaction.dart';

class TransactionsPage {
  const TransactionsPage({required this.total, required this.items});
  final int total;
  final List<Transaction> items;
}

/// Callers: `transactions_provider.dart` (Riverpod providers watched by
/// `transactions_screen.dart`). Mirrors `backend/app/transactions/router.py`'s
/// `POST/GET /transactions/`, `PATCH/DELETE /transactions/{id}`.
/// Instruction: "Continue with Phase 2" (Transactions/Expenses/Budgets/Goals,
/// per the approved migration plan).
class TransactionsApi {
  TransactionsApi(this._client);
  final ApiClient _client;

  Future<TransactionsPage> list({
    String? accountId,
    TransactionType? transactionType,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.dio.get('/transactions/', queryParameters: {
        if (accountId case String aid) 'account_id': aid,
        if (transactionType case TransactionType tt) 'transaction_type': tt.name,
        if (dateFrom case DateTime df) 'date_from': _dateOnly(df),
        if (dateTo case DateTime dt) 'date_to': _dateOnly(dt),
        if (category != null && category.isNotEmpty) 'category': category,
        'limit': limit,
        'offset': offset,
      });
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List).map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
      return TransactionsPage(total: data['total'] as int, items: items);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Transaction> create({
    String? accountId,
    required TransactionType transactionType,
    required String category,
    String? description,
    required String amount,
    required DateTime transactionDate,
    String? merchantName,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post('/transactions/', data: {
        if (accountId case String aid) 'account_id': aid,
        'transaction_type': transactionType.name,
        'category': category,
        if (description case String d) 'description': d,
        'amount': amount,
        'transaction_date': _dateOnly(transactionDate),
        if (merchantName case String m) 'merchant_name': m,
        if (notes case String n) 'notes': n,
      });
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Transaction> update(
    String transactionId, {
    String? accountId,
    TransactionType? transactionType,
    String? category,
    String? description,
    String? amount,
    DateTime? transactionDate,
    String? merchantName,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.patch('/transactions/$transactionId', data: {
        if (accountId case String aid) 'account_id': aid,
        if (transactionType case TransactionType tt) 'transaction_type': tt.name,
        if (category case String c) 'category': c,
        if (description case String d) 'description': d,
        if (amount case String a) 'amount': a,
        if (transactionDate case DateTime td) 'transaction_date': _dateOnly(td),
        if (merchantName case String m) 'merchant_name': m,
        if (notes case String n) 'notes': n,
      });
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> delete(String transactionId) async {
    try {
      await _client.dio.delete('/transactions/$transactionId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
