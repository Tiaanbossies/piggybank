import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/categorize_result.dart';
import '../models/import_job.dart';
import '../models/ocr_result.dart';

class ImportsApi {
  ImportsApi(this._client);
  final ApiClient _client;

  Future<List<BankTemplate>> listTemplates() async {
    try {
      final response = await _client.dio.get('/imports/templates');
      return (response.data as List)
          .map((e) => BankTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<List<ImportJob>> listImports() async {
    try {
      final response = await _client.dio.get('/imports/');
      return (response.data as List).map((e) => ImportJob.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<ImportJob> uploadCsv({
    required String filePath,
    required String filename,
    String? template,
    String? accountId,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final response = await _client.dio.post(
        '/imports/',
        data: form,
        queryParameters: {
          if (template case String t) 'template': t,
          if (accountId case String aid) 'account_id': aid,
        },
      );
      return ImportJob.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<OcrResult> ocrReceipt({required String filePath, required String filename}) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final response = await _client.dio.post('/imports/ocr', data: form);
      return OcrResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<CategorizeBatchResult> categorizeTransactionsBatch() async {
    try {
      final response = await _client.dio.post('/transactions/categorize-batch');
      return CategorizeBatchResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}
