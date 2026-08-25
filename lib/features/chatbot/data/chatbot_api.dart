import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../models/chat_message.dart';

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
      );
      return ChatReply.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final chatbotApiProvider = Provider<ChatbotApi>((ref) => ChatbotApi(ref.watch(apiClientProvider)));
