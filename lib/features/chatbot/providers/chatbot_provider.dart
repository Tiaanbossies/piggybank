import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chatbot_api.dart';
import '../models/chat_message.dart';

/// Mutable in-memory conversation state — follows the same `StateNotifier`
/// pattern as `ComparisonController` (comparison_provider.dart), the
/// codebase's precedent for a feature that accumulates client-side state
/// across several actions rather than a single `FutureProvider` fetch.
/// Deliberately not persisted: the backend is stateless per-request (see
/// `ChatbotApi`), so there is nothing server-side to resume even if the
/// client kept history across app restarts.
class ChatbotState {
  const ChatbotState({this.messages = const [], this.sending = false});

  final List<ChatMessage> messages;
  final bool sending;

  ChatbotState copyWith({List<ChatMessage>? messages, bool? sending}) =>
      ChatbotState(messages: messages ?? this.messages, sending: sending ?? this.sending);
}

class ChatbotController extends StateNotifier<ChatbotState> {
  ChatbotController(this._ref) : super(const ChatbotState());

  final Ref _ref;

  /// Sends [text] plus the full prior history (the backend keeps no
  /// server-side memory). On failure the optimistically-added user message
  /// is rolled back and the error is rethrown so the screen can decide how
  /// to present it (paywall dialog vs. inline error), matching every other
  /// gated action in this app.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    final history = [...state.messages, ChatMessage(role: ChatRole.user, content: trimmed)];
    state = state.copyWith(messages: history, sending: true);

    try {
      final reply = await _ref.read(chatbotApiProvider).sendMessage(history);
      state = state.copyWith(
        messages: [...history, ChatMessage(role: ChatRole.assistant, content: reply.reply)],
        sending: false,
      );
    } catch (e) {
      state = state.copyWith(messages: history.sublist(0, history.length - 1), sending: false);
      rethrow;
    }
  }
}

final chatbotControllerProvider = StateNotifierProvider.autoDispose<ChatbotController, ChatbotState>((ref) {
  return ChatbotController(ref);
});
