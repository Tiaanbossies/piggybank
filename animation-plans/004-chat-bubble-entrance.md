# 004 — Entrance animation for new chat bubbles only

- **Status**: TODO
- **Commit**: 8a264ab
- **Severity**: MEDIUM
- **Category**: Missed opportunities (spatial consistency)
- **Estimated scope**: 1 file

## Problem

`lib/features/chatbot/screens/chatbot_screen.dart:156-165` renders the message list as a plain
`ListView`; every `_ChatBubble` (both the user's own message and the bot's reply) appears instantly:

```dart
// current
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
```

`_ChatBubble` (lines 213-248) is currently a `StatelessWidget`:

```dart
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final ChatMessage message;
  // ...build() unchanged, see file...
}
```

`ChatMessage` (`lib/features/chatbot/models/chat_message.dart`) has no id/timestamp — only `role`
and `content` — so entrance-tracking cannot key off message identity/content. It must instead key
off **list index**, using Flutter's own child-identity mechanism (a `ValueKey`) to distinguish "a
bubble that already existed" from "a bubble newly inserted at the bottom."

## Target

Give each `_ChatBubble` a `ValueKey(index)` and convert it to a `StatefulWidget` that plays a
one-shot fade+rise on `initState` — but only for indices at or beyond the message count captured
when the screen first mounted, so history already in `state.messages` on first paint does not
replay the animation.

```dart
// target — in _ChatbotScreenState
class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _error;
  String? _retryText;
  late final int _animatedFloor = ref.read(chatbotControllerProvider).messages.length;

  // ...existing dispose/_scrollToBottom/_send unchanged...
```

```dart
// target — the ListView (replaces lines 156-165)
: ListView(
    controller: _scrollController,
    padding: const EdgeInsets.all(16),
    children: [
      for (var i = 0; i < state.messages.length; i++)
        _ChatBubble(key: ValueKey(i), message: state.messages[i], animate: i >= _animatedFloor),
      if (state.sending) const _TypingBubble(),
      if (_error != null)
        _ErrorBubble(message: _error!, onRetry: _retryText == null ? null : () => _send(_retryText)),
    ],
  ),
```

```dart
// target — _ChatBubble (replaces lines 213-248)
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
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final match = isUser ? null : _statCardPattern.firstMatch(widget.message.content);

    final bubble = Align(
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
                widget.message.content,
                style: TextStyle(color: isUser ? colorScheme.onPrimary : colorScheme.onSurface),
              )
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
```

`AppMotion.stateChange` (200ms) + `Curves.easeOut` matches the AUDIT.md entrance budget for
occasional UI (tooltips/small popovers land at 125-200ms; this sits at the top of that range since
it carries an 8px rise, not a bare fade). The `value: widget.animate ? 0 : 1` initial controller
value means a non-animating bubble (history) renders fully opaque/settled on its very first frame —
no flash-then-fix.

## Repo conventions to follow

- Import `AppMotion` from `lib/core/theme/app_motion.dart` (plan 001). If plan 001 has not landed,
  stop and land it first.
- `_StatCardReply`, `_ErrorBubble`, `_TypingBubble` and the `_statCardPattern` regex are unchanged —
  only `_ChatBubble` and its call site change.

## Steps

1. Confirm `lib/core/theme/app_motion.dart` exists (plan 001). If missing, stop.
2. In `lib/features/chatbot/screens/chatbot_screen.dart`, add
   `import '../../../core/theme/app_motion.dart';` to the imports.
3. Add the `late final int _animatedFloor = ref.read(chatbotControllerProvider).messages.length;`
   field to `_ChatbotScreenState`, as shown in "Target" (placed alongside the other fields at the
   top of the class — do not move any existing field).
4. Replace the `ListView`'s `children` list (lines 156-165) with the indexed version shown in
   "Target", replacing the `for (final message in state.messages) _ChatBubble(message: message)`
   line specifically.
5. Replace the `_ChatBubble` class (lines 213-248) with the `StatefulWidget` version shown in
   "Target" — note every reference to `message` inside `build()` becomes `widget.message`.

## Boundaries

- Do NOT touch `_StatCardReply`, `_ErrorBubble`, `_TypingBubble`, or the scroll-to-bottom logic
  (`_scrollToBottom`, lines 53-62) — that animation is already correct and out of scope.
- Do NOT animate historical messages already present when the screen first mounts (`i < _animatedFloor`)
  — this must only affect messages appended after the screen is already showing.
- Do NOT add `prefers-reduced-motion` gating beyond what's shown — a 200ms fade+8px rise is gentle
  enough per AUDIT.md §6 to keep as-is even under reduced motion (it's an opacity-led transition,
  not a large movement); if you want to gate it anyway, drop only the `Transform.translate` offset
  (keep it at 0) when `MediaQuery.of(context).disableAnimations` is true, never drop the fade.
- If a step doesn't match the code you find (drift since commit `8a264ab`), STOP and report instead
  of improvising.

## Verification

- **Mechanical**: `flutter analyze` (0 issues), then
  `flutter test test/features/chatbot/screens/chatbot_screen_test.dart` — all existing tests must
  pass unchanged (they use `pumpAndSettle()` throughout, which resolves the new 200ms entrance).
- **Feel check**: run the app, open the Assistant tab with existing chat history, and confirm:
  - Historical messages appear instantly (no fade/rise) on screen entry.
  - Sending a new message: the user's bubble and the bot's reply both fade+rise in from 8px below,
    settling within 200ms.
  - Rapidly sending several messages in a row does not stack or glitch the animation (each bubble's
    `ValueKey(i)` is stable and unique per index, so Flutter never confuses two bubbles' state).
  - In DevTools (Animations panel), set playback to 10% and confirm the motion is a fade+small rise,
    not a slide from the side.
- **Done when**: `flutter analyze` is clean, `chatbot_screen_test.dart` passes unchanged, and the
  feel check above holds.
