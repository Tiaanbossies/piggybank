import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/motion/press_scale.dart';
import '../../../shared/widgets/bubble_border.dart';
import '../../../shared/widgets/mascot_moment.dart';
import '../../../shared/widgets/paywall_dialog.dart';
import '../../../shared/widgets/tab_app_bar.dart';
import '../models/chat_message.dart';
import '../providers/chatbot_provider.dart';
import '../providers/suggested_questions_provider.dart';

/// Blueprint Step 8. An ongoing conversational thread — bubbles left/right by
/// role, most-recent at the bottom. Backend is confirmed synchronous/non-streaming
/// (`ChatbotApi` docs), so a send shows a single typing-indicator bubble
/// then the complete reply, never token-by-token.
///
/// Entry point: the bottom nav's "Assistant" tab (see `app_router.dart`'s
/// `/assistant` branch and `app_shell.dart`'s destinations list). Previously
/// reached only via a Settings row (`GroupRow`, `Navigator.push`); that row
/// was removed once this became a primary tab, to avoid two navigation
/// paths to the same screen. Formerly sat alongside an older Q&A-history
/// "Insights" screen at the 4th tab slot — that screen overlapped with this
/// one ("ask about your finances" in two places) and has since been deleted
/// entirely, not just unrouted (see the nav/Stitch/OTA-update blueprint's
/// Step 2). A differently-scoped, differently-named trends/analytics screen
/// may be added later under `lib/features/trends/`, not this path.
class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

/// Opens Penny's tab with [question] waiting in the input box. Used from
/// pushed screens (the Savings plan), which stay where they were on their
/// own tab. Without a router (widget tests) only the draft is set.
void askPenny(BuildContext context, WidgetRef ref, String question) {
  ref.read(chatDraftProvider.notifier).state = question;
  GoRouter.maybeOf(context)?.go('/assistant');
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _error;
  String? _retryText;
  // Bubbles already there when the tab opens don't animate; every one
  // after does. Read up front: read lazily, it would count the first
  // message too, and that one would never rise in (M30).
  late final int _animatedFloor;

  @override
  void initState() {
    super.initState();
    _animatedFloor = ref.read(chatbotControllerProvider).messages.length;
    // A draft set before this tab was first built. Taken after the frame,
    // because clearing a provider mid-build isn't allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _takeDraft(ref.read(chatDraftProvider));
    });
  }

  /// Moves a waiting question into the input box, cursor at the end, and
  /// clears it so it isn't put back on the next visit.
  void _takeDraft(String? draft) {
    if (draft == null || draft.trim().isEmpty) return;
    _inputController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    ref.read(chatDraftProvider.notifier).state = null;
  }

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
        duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
        curve: AppMotion.easeOut,
      );
    });
  }

  Future<void> _send([String? overrideText]) async {
    final text = overrideText ?? _inputController.text;
    if (text.trim().isEmpty) return;
    // The send lands (M30): one light tap as the bubble rises.
    unawaited(AppHaptics.light());
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
          unawaited(showPaywallPrompt(context, message: e.message));
        }
      } else if (mounted) {
        setState(() {
          _error = e.message;
          _retryText = text;
        });
      }
    } catch (_) {
      // Anything else (a reply that doesn't parse, say) still gets a visible
      // error and a Retry, never a silent return to the welcome screen.
      if (mounted) {
        setState(() {
          _error = 'Please try again.';
          _retryText = text;
        });
      }
    }
  }

  /// A suggested question (M32): the chip's press scale has already
  /// started on touch-down; a selection tick, then it sends like any other.
  void _ask(String question) {
    unawaited(AppHaptics.selection());
    _send(question);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotControllerProvider);
    final suggestions = ref.watch(suggestedQuestionsProvider);
    // A failed first message rolls back out of the history, so the error
    // keeps the thread up: otherwise the welcome comes back and the send
    // looks like it did nothing (QA H1).
    final empty = state.messages.isEmpty && !state.sending && _error == null;
    // A draft set while this tab is already alive in the shell.
    ref.listen<String?>(chatDraftProvider, (_, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _takeDraft(ref.read(chatDraftProvider));
      });
    });
    return Scaffold(
      appBar: const TabAppBar(
        title: 'Penny',
        subtitle: 'Ask me anything about your money',
        titleLeading: PennyImage(MascotMoment.welcoming, size: 40),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
                switchInCurve: AppMotion.easeOut,
                switchOutCurve: AppMotion.easeOut,
                // The chips step aside as the first message goes (M30): the
                // welcome sinks and fades while the thread takes its place.
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child.key == const ValueKey('chat-welcome')
                      ? SlideTransition(
                          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
                          child: child,
                        )
                      : child,
                ),
                child: empty
                    ? _Welcome(
                        key: const ValueKey('chat-welcome'),
                        suggestions: suggestions,
                        onAsk: state.sending ? null : _ask,
                      )
                    : ListView(
                        key: const ValueKey('chat-thread'),
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpace.gutter),
                        children: [
                          for (var i = 0; i < state.messages.length; i++)
                            _ChatBubble(key: ValueKey(i), message: state.messages[i], animate: i >= _animatedFloor),
                          if (state.sending) const _ThinkingSlot(),
                          // The question that failed, shown where it was
                          // asked; Retry sends it again.
                          if (_error != null && _retryText != null && !state.sending)
                            _ChatBubble(
                              key: const ValueKey('chat-failed'),
                              message: ChatMessage(role: ChatRole.user, content: _retryText!.trim()),
                              animate: false,
                            ),
                          if (_error != null)
                            _ErrorBubble(message: _error!, onRetry: _retryText == null ? null : () => _send(_retryText)),
                        ],
                      ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s8, AppSpace.gutter, AppSpace.s12),
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
                        // The theme's pill input (spec §3).
                        decoration: const InputDecoration(hintText: 'Ask a question…'),
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

/// Before the first message: welcoming Penny, a hello, and up to three
/// data-aware questions as outlined pills (spec §4.1 Penny, M32).
class _Welcome extends StatelessWidget {
  const _Welcome({required this.suggestions, required this.onAsk, super.key});

  final List<String> suggestions;
  final ValueChanged<String>? onAsk;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotMoment(asset: MascotMoment.welcoming, size: 120, motion: MascotMotion.fadeIn),
            const SizedBox(height: AppSpace.s16),
            Text("Hi, I'm Penny", textAlign: TextAlign.center, style: text.titleLarge),
            const SizedBox(height: AppSpace.s8),
            Text(
              'I can help you track spending, check your budgets, or analyse your investments.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: t.muted),
            ),
            const SizedBox(height: AppSpace.s20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final q in suggestions)
                  PressScale(
                    child: OutlinedButton(
                      key: ValueKey('suggestion-$q'),
                      onPressed: onAsk == null ? null : () => onAsk!(q),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.ink,
                        side: BorderSide(color: t.outline),
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
                      ),
                      child: Text(q, textAlign: TextAlign.center),
                    ),
                  ),
              ],
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

class _ChatBubble extends StatefulWidget {
  const _ChatBubble({required this.message, required this.animate, super.key});
  final ChatMessage message;
  final bool animate;

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.stateChange,
    value: 1,
  );
  late final Animation<double> _curved = CurvedAnimation(parent: _controller, curve: AppMotion.easeOut);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // A new bubble rises 8 dp and fades in over 200 ms (M30, M31); under
    // reduced motion it's simply there.
    if (widget.animate && !context.reducedMotion) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isUser = widget.message.role == ChatRole.user;
    final match = isUser ? null : _statCardPattern.firstMatch(widget.message.content);

    // Replies on surface, the user's in primary, each with a tail toward
    // its speaker (spec §3 Speech bubble).
    final bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
        constraints: BoxConstraints(minWidth: 64, maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: ShapeDecoration(
          color: isUser ? t.primary : t.surface,
          shape: BubbleBorder(tail: isUser ? BubbleTail.bottomEnd : BubbleTail.bottomStart),
          shadows: isUser ? null : AppShadows.level1(Theme.of(context).brightness),
        ),
        child: match == null
            ? Text(widget.message.content, style: TextStyle(color: isUser ? t.onPrimary : t.ink))
            : _StatCardReply(fullText: widget.message.content, match: match),
      ),
    );

    if (!widget.animate) return bubble;
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) => Opacity(
        opacity: _curved.value,
        child: Transform.translate(offset: Offset(0, (1 - _curved.value) * 8), child: child),
      ),
      child: bubble,
    );
  }
}

class _StatCardReply extends StatelessWidget {
  const _StatCardReply({required this.fullText, required this.match});
  final String fullText;
  final RegExpMatch match;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dir = (match.namedGroup('dir') ?? '').toLowerCase();
    final isDown = dir == 'lower' || dir == 'down' || dir == 'less';
    final label = (match.namedGroup('label') ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(fullText, style: TextStyle(color: t.ink)),
        const SizedBox(height: AppSpace.s12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s12),
          decoration: BoxDecoration(color: t.sunk, borderRadius: AppRadius.tileAll),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label.isNotEmpty)
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.muted),
                ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'R ${match.namedGroup('amount')}',
                    style: moneyTextStyle(context, fontSize: 20),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Icon(isDown ? Icons.trending_down : Icons.trending_up, size: 16, color: t.muted),
                  Text(
                    ' ${match.namedGroup('pct')}%',
                    style: TextStyle(color: t.muted, fontWeight: FontWeight.w700, fontSize: 12),
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
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
        constraints: BoxConstraints(minWidth: 64, maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: ShapeDecoration(
          color: t.dangerContainer,
          shape: const BubbleBorder(tail: BubbleTail.bottomStart),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Sorry, I'm having trouble with that. $message", style: TextStyle(color: t.onDangerContainer)),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.s4),
              InkWell(
                onTap: onRetry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: t.onDangerContainer,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Penny's reply slot while she thinks (M31): the 40 dp thinking pose with
/// a 2 dp bob (static under reduced motion) that goes when the reply lands.
/// After [patience], "Still working on it…" fades in beside her.
class _ThinkingSlot extends StatefulWidget {
  const _ThinkingSlot();

  static const patience = AppMotion.pennyPatience;

  @override
  State<_ThinkingSlot> createState() => _ThinkingSlotState();
}

class _ThinkingSlotState extends State<_ThinkingSlot> {
  bool _slow = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_ThinkingSlot.patience, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Penny is thinking',
              child: const MascotMoment(
                key: Key('penny-thinking'),
                asset: MascotMoment.thinking,
                size: 40,
                motion: MascotMotion.bob,
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Flexible(
              child: AnimatedSwitcher(
                duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
                switchInCurve: AppMotion.easeOut,
                child: _slow
                    ? Text(
                        'Still working on it…',
                        key: const Key('still-working'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
