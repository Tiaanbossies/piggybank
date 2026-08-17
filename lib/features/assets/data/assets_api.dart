import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/asset.dart';

class AssetsApi {
  AssetsApi(this._client);
  final ApiClient _client;

  Future<List<Asset>> list() async {
    try {
      final response = await _client.dio.get('/assets/', queryParameters: {'limit': 200});
      final data = response.data as Map<String, dynamic>;
      return (data['items'] as List).map((e) => Asset.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Asset> create({
    required AssetType assetType,
    required String name,
    required String currentValue,
    DateTime? valuationDate,
    String? institutionName,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post('/assets/', data: {
        'asset_type': assetTypeToJson(assetType),
        'name': name,
        'current_value': currentValue,
        if (valuationDate != null) 'valuation_date': _dateOnly(valuationDate),
        if (institutionName != null) 'institution_name': institutionName,
        if (notes != null) 'notes': notes,
      });
      return Asset.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Asset> update(
    String assetId, {
    AssetType? assetType,
    String? name,
    String? currentValue,
    DateTime? valuationDate,
    String? institutionName,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.patch('/assets/$assetId', data: {
        if (assetType != null) 'asset_type': assetTypeToJson(assetType),
        if (name != null) 'name': name,
        if (currentValue != null) 'current_value': currentValue,
        if (valuationDate != null) 'valuation_date': _dateOnly(valuationDate),
        if (institutionName != null) 'institution_name': institutionName,
        if (notes != null) 'notes': notes,
      });
      return Asset.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> delete(String assetId) async {
    try {
      await _client.dio.delete('/assets/$assetId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
