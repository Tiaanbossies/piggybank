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

const _suggestedQuestions = [
  'How much did I spend on dining?',
  'Am I on track with my budget?',
  'Show my net worth trend',
];

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _error;
  String? _retryText;

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

  Future<void> _send([String? overrideText]) async {
    final text = overrideText ?? _inputController.text;
    if (text.trim().isEmpty) return;
    setState(() {
      _error = null;
      _retryText = null;
    });
    if (overrideText == null) _inputController.clear();
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
        setState(() {
          _error = e.message;
          _retryText = text;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotControllerProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const IconChip(icon: Icons.savings, size: 32),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Financial Assistant', style: TextStyle(fontSize: 16)),
                Text(
                  'Ask me anything about your money',
                  style: TextStyle(fontSize: 11, color: semantic?.textMuted, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
      ),
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
                            const IconChip(icon: Icons.savings, size: 56),
                            const SizedBox(height: 16),
                            Text(
                              "Hi, I'm your financial assistant",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'I can help you track spending, check your budgets, or analyze your investments.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: semantic?.textMuted),
                            ),
                            const SizedBox(height: 20),
                            for (final q in _suggestedQuestions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: state.sending ? null : () => _send(q),
                                    style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                                    child: Text(q),
                                  ),
                                ),
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
                        if (_error != null)
                          _ErrorBubble(message: _error!, onRetry: _retryText == null ? null : () => _send(_retryText)),
                      ],
                    ),
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

/// Matches an amount like "R 4,230" or "R4230.50" plus a trailing "12% lower"
/// / "8% higher" style clause, so a bot reply that states a money figure
/// with a period-over-period comparison renders as a compact stat card
/// instead of a plain bubble. Any reply that doesn't match this shape (the
/// overwhelming majority) falls back to the plain-text bubble unchanged.
final _statCardPattern = RegExp(
  r'(?<label>[A-Za-z ]{3,40}?)[:\s]*\bR\s?(?<amount>[\d][\d,]*\.?\d*)\b[^%]{0,40}?(?<pct>\d{1,3}(?:\.\d+)?)%\s*(?<dir>lower|higher|up|down|less|more)',
  caseSensitive: false,
);

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final match = isUser ? null : _statCardPattern.firstMatch(message.content);

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
        child: match == null
            ? Text(
                message.content,
                style: TextStyle(color: isUser ? colorScheme.onPrimary : colorScheme.onSurface),
              )
            : _StatCardReply(fullText: message.content, match: match),
      ),
    );
  }
}

class _StatCardReply extends StatelessWidget {
  const _StatCardReply({required this.fullText, required this.match});
  final String fullText;
  final RegExpMatch match;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final dir = (match.namedGroup('dir') ?? '').toLowerCase();
    final isDown = dir == 'lower' || dir == 'down' || dir == 'less';
    final label = (match.namedGroup('label') ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(fullText, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label.isNotEmpty)
                Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: 11, color: semantic?.textMuted, fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'R ${match.namedGroup('amount')}',
                    style: moneyTextStyle(context, fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Icon(isDown ? Icons.trending_down : Icons.trending_up, size: 16, color: semantic?.success),
                  Text(
                    ' ${match.namedGroup('pct')}%',
                    style: TextStyle(color: semantic?.success, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: semantic?.dangerChipBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Sorry, I'm having trouble with that. $message", style: TextStyle(color: semantic?.danger)),
            if (onRetry != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(color: semantic?.danger, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
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
