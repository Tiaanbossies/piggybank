import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';

/// `ApiClient`-based, mirrors `NotificationPrefsApi`. Wraps `full_name` and
/// `salary_day` on `PATCH /auth/me` — there is no dedicated profile route,
/// the backend reuses the same profile-update endpoint every Settings
/// sub-screen that edits `User` fields already goes through.
class ProfileApi {
  ProfileApi(this._client);
  final ApiClient _client;

  /// Only the passed fields are sent — `PATCH /auth/me` treats each field as
  /// independently optional (`exclude_unset`), unlike notification_preferences'
  /// whole-dict replace, so a null [salaryDay] here means "don't change it",
  /// not "clear it".
  Future<void> updateProfile({String? fullName, int? salaryDay}) async {
    try {
      await _client.dio.patch('/auth/me', data: {
        if (fullName != null) 'full_name': fullName,
        if (salaryDay != null) 'salary_day': salaryDay,
      });
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) => ProfileApi(ref.watch(apiClientProvider)));
