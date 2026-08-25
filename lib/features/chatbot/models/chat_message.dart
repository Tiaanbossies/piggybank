/// Plain JSON model for `/api/chatbot/chat` — mirrors
/// `backend/app/chatbot/schemas.py`'s `ChatMessageIn`/`ChatRequest`/`ChatResponse`.
/// The backend is stateless and synchronous (no streaming, no server-side
/// conversation memory) — the client resends the full message history with
/// every request, per `piggybank-production-completion.md` Step 8's context
/// brief.
library;

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final ChatRole role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role.name, 'content': content};
}

class ChatReply {
  const ChatReply({required this.reply, required this.model, required this.webSearchEnabled});

  final String reply;
  final String model;
  final bool webSearchEnabled;

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
        reply: json['reply'] as String,
        model: json['model'] as String,
        webSearchEnabled: json['web_search_enabled'] as bool? ?? false,
      );
}
