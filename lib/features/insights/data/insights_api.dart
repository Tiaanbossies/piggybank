import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../models/insight.dart';

/// `ApiClient`-based, mirrors `ConsentsApi`. Wraps
/// `backend/app/insights/router.py`'s `ask`/`list` endpoints — `require_pro_tier`
/// means a free-tier caller gets a 402, surfaced as `ApiError.isPaywall` like
/// every other gated feature in this app. `get`/`delete` exist on the backend
/// but have no UI use here (no per-insight detail or delete affordance in the
/// task list), so they're deliberately not wrapped.
class InsightsApi {
  InsightsApi(this._client);
  final ApiClient _client;

  Future<InsightAskResult> ask(String question) async {
    try {
      final response = await _client.dio.post(
        '/insights',
        data: {'question': question},
        // AI-generated insights observed up to ~26s in QA — see fix-it plan
        // Step 3 / QA H6.
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      return InsightAskResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<List<Insight>> list() async {
    try {
      final response = await _client.dio.get('/insights/');
      return (response.data as List).map((e) => Insight.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final insightsApiProvider = Provider<InsightsApi>((ref) => InsightsApi(ref.watch(apiClientProvider)));
