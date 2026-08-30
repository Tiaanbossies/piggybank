import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_controller.dart';
import '../models/subscription.dart';

/// `ApiClient`-based, mirrors `ConsentsApi`/`ImportsApi`. Wraps
/// `backend/app/subscriptions/router.py`'s endpoints (mounted at
/// `/subscription`, singular — not `/subscriptions/` as an earlier draft of
/// the production-completion blueprint assumed).
///
/// `upgrade()` (an instant DB-flip, no real charge) is gone as of Step 6 of
/// `piggybank-launch-readiness.md` — replaced by [startCheckout], which
/// kicks off a real PayFast checkout. Pro is only granted once PayFast's
/// ITN webhook confirms payment server-side; the client never grants it
/// directly.
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

  /// Starts a PayFast checkout and returns the absolute URL to open in the
  /// system browser. Does NOT grant Pro — that only happens once PayFast's
  /// ITN webhook confirms payment (poll [fetch] after the browser returns).
  Future<Uri> startCheckout() async {
    try {
      final response = await _client.dio.post('/subscription/checkout');
      final data = response.data as Map<String, dynamic>;
      final path = data['checkout_page_url'] as String;
      return Uri.parse('${ApiConfig.baseUrl}$path');
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
