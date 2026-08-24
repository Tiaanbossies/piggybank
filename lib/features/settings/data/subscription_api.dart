import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../models/subscription.dart';

/// `ApiClient`-based, mirrors `ConsentsApi`/`ImportsApi`. Wraps
/// `backend/app/subscriptions/router.py`'s three endpoints (mounted at
/// `/subscription`, singular — not `/subscriptions/` as an earlier draft of
/// the production-completion blueprint assumed).
class SubscriptionApi {
  SubscriptionApi(this._client);
  final ApiClient _client;

  Future<Subscription> fetch() async {
    try {
      final response = await _client.dio.get('/subscription');
      return Subscription.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Subscription> upgrade() async {
    try {
      final response = await _client.dio.post('/subscription/upgrade');
      return Subscription.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Subscription> cancel() async {
    try {
      final response = await _client.dio.post('/subscription/cancel');
      return Subscription.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final subscriptionApiProvider = Provider<SubscriptionApi>((ref) => SubscriptionApi(ref.watch(apiClientProvider)));
