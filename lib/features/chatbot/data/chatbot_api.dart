import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../models/chat_message.dart';
import '../models/policy_research.dart';

/// Wraps `backend/app/chatbot/router.py`'s single `POST /chatbot/chat`
/// endpoint — synchronous, no pagination, no conversation id. `require_pro_tier`
/// on the backend means a free-tier caller gets a 402, surfaced as
/// `ApiError.isPaywall` like every other gated feature in this app.
class ChatbotApi {
  ChatbotApi(this._client);
  final ApiClient _client;

  Future<ChatReply> sendMessage(List<ChatMessage> history) async {
    try {
      final response = await _client.dio.post(
        '/chatbot/chat',
        data: {'messages': [for (final m in history) m.toJson()]},
        // Real Ollama inference can take well beyond the client's short
        // global default — see fix-it plan Step 3 / QA H6. Kept above the
        // server's own 120 s Ollama timeout, so a slow model comes back as
        // the server's 503 rather than the client giving up first.
        options: Options(receiveTimeout: const Duration(seconds: 150)),
      );
      return ChatReply.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout) {
        throw const ApiError(statusCode: 0, message: 'Penny took too long to answer. Try again in a moment.');
      }
      throw ApiClient.errorFrom(e);
    }
  }

  /// Penny's reading of one insurance policy against published sources
  /// (Pro, 5 a day). The server searches before Penny writes, so this can
  /// take longer than a chat reply.
  Future<PolicyResearch> researchPolicy(String policyId) async {
    try {
      final response = await _client.dio.post(
        '/chatbot/policy-check/$policyId',
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      return PolicyResearch.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final chatbotApiProvider = Provider<ChatbotApi>((ref) => ChatbotApi(ref.watch(apiClientProvider)));
