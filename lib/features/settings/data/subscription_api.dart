import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../models/subscription.dart';

/// `ApiClient`-based, mirrors `ConsentsApi`/`ImportsApi`. Wraps
/// `backend/app/subscriptions/router.py`'s endpoints (mounted at
/// `/subscription`, singular — not `/subscriptions/` as an earlier draft of
/// the production-completion blueprint assumed).
///
/// Read-only since founder-review-fixes PR 1: in-app PayFast checkout and
/// cancel are gone. Pro is a free beta grant until the backend's
/// `PRO_PROMO_UNTIL`; paid Pro will come through Google Play Billing.
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
}

final subscriptionApiProvider = Provider<SubscriptionApi>((ref) => SubscriptionApi(ref.watch(apiClientProvider)));
