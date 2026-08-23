import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/consents/consent_models.dart';

/// `ApiClient`-based (i.e. runs post-bootstrap, with the bearer/refresh
/// interceptor already wired up) — mirrors `AccountsApi`. Contrast with the
/// raw-Dio `requiredConsents`/`acceptedConsents` on `AuthApi`, which run
/// during login/register/restoreSession before an `ApiClient` exists.
class ConsentsApi {
  ConsentsApi(this._client);
  final ApiClient _client;

  Future<List<RequiredDocument>> listRequired() async {
    try {
      final response = await _client.dio.get('/consents/required');
      final items = response.data as List;
      return items.map((e) => RequiredDocument.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<List<ConsentRecord>> listAccepted() async {
    try {
      final response = await _client.dio.get('/consents/');
      final items = response.data as List;
      return items.map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<ConsentRecord> accept({required String documentType, required String documentVersion}) async {
    try {
      final response = await _client.dio.post('/consents/', data: {
        'document_type': documentType,
        'document_version': documentVersion,
      });
      return ConsentRecord.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final consentsApiProvider = Provider<ConsentsApi>((ref) => ConsentsApi(ref.watch(apiClientProvider)));
