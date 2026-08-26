import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/paywall_dialog.dart';
import '../models/chat_message.dart';
import '../providers/chatbot_provider.dart';

/// Blueprint Step 8. An ongoing conversational thread — bubbles left/right by
/// role, most-recent at the bottom — deliberately distinct from Insights'
/// planned "Q&A history list" layout (a flat list of one-off question/answer
/// pairs, no back-and-forth). Backend is confirmed synchronous/non-streaming
/// (`ChatbotApi` docs), so a send shows a single typing-indicator bubble
/// then the complete reply, never token-by-token.
///
/// Entry point: pushed from Settings (`GroupRow` alongside Subscription,
/// Security, etc.), not from the Insights tab — Insights is still Step 7's
/// bare "coming soon" placeholder with no real navigation surface to push
/// from, whereas Settings already lists every other real, gated feature the
/// same way. Revisit if/when Step 7 gives Insights its own real screen.
class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    setState(() => _error = null);
    _inputController.clear();
    _scrollToBottom();
    try {
      await ref.read(chatbotControllerProvider.notifier).sendMessage(text);
      _scrollToBottom();
    } on ApiError catch (e) {
      if (e.isPaywall) {
        if (mounted) {
          Navigator.of(context).pop();
          unawaited(showPaywallPrompt(context, message: e.message));
        }
      } else if (mounted) {
        setState(() => _error = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty && !state.sending
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const IconChip(icon: Icons.smart_toy_outlined, size: 56),
                            const SizedBox(height: 16),
                            Text(
                              'Ask about your accounts, budgets, or investments.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).extension<AppSemanticColors>()?.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final message in state.messages) _ChatBubble(message: message),
                        if (state.sending) const _TypingBubble(),
                      ],
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).extension<AppSemanticColors>()?.danger)),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !state.sending,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Ask a question…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: state.sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primary : semantic?.accentChipBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isUser ? colorScheme.onPrimary : colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: semantic?.accentChipBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
        ),
      ),
    );
  }
}
