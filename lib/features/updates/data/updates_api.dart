import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../models/latest_release.dart';

/// Thin client for the backend's `GET /updates/latest` — unauthenticated by
/// design (a fresh install has no token yet) but tailnet-only by
/// construction, per `piggybank-backend/backend/app/updates/router.py`'s own
/// doc comment. Used only to compare this install's build number against
/// the latest published release.
class UpdatesApi {
  UpdatesApi(this._client);
  final ApiClient _client;

  /// Returns `null` (not an error) when the backend has never published a
  /// release yet — the endpoint 404s in that case, which is an expected
  /// fresh-deployment state, not a failure worth surfacing to the user.
  Future<LatestRelease?> latest() async {
    try {
      final response = await _client.dio.get('/updates/latest');
      return LatestRelease.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiClient.errorFrom(e);
    }
  }
}

final updatesApiProvider = Provider<UpdatesApi>((ref) => UpdatesApi(ref.watch(apiClientProvider)));
