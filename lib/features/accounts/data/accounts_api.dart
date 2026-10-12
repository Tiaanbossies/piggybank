import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/account.dart';

class AccountsApi {
  AccountsApi(this._client);
  final ApiClient _client;

  Future<List<Account>> list({bool includeInactive = false}) async {
    try {
      final response = await _client.dio.get('/accounts/', queryParameters: {'include_inactive': includeInactive});
      final items = (response.data as Map<String, dynamic>)['items'] as List;
      return items.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Account> create({
    required String name,
    required String accountType,
    required String currency,
    String? institutionName,
    String? openingBalance,
  }) async {
    try {
      final response = await _client.dio.post('/accounts/', data: {
        'name': name,
        'account_type': accountType,
        'currency': currency,
        if (institutionName case String name) 'institution_name': name,
        if (openingBalance case String balance) 'opening_balance': balance,
      });
      return Account.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Soft-delete (deactivate) — matches the backend's non-uniform delete
  /// semantics (accounts are the one domain that's restorable).
  Future<void> deactivate(String accountId) async {
    try {
      await _client.dio.delete('/accounts/$accountId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Update account details (name, institution), or restore a deactivated
  /// account with `isActive: true` (QA D2a). A restore past the free tier's
  /// account limit comes back as a 402.
  Future<Account> update(
    String accountId, {
    String? name,
    String? institutionName,
    bool? isActive,
  }) async {
    try {
      final response = await _client.dio.patch('/accounts/$accountId', data: {
        if (name case String n) 'name': n,
        if (institutionName case String i) 'institution_name': i,
        if (isActive case bool a) 'is_active': a,
      });
      return Account.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}
