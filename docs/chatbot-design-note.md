# Chatbot UI — design note (blueprint Step 8)

No mockup or design-brief direction exists for this feature — both
`docs/stitch-design-brief.md` and `docs/ui-ux-mockup-brief.md` explicitly defer
it ("mention only"). This note is the record of the decisions actually made.

## Layout: conversational thread, not a Q&A history list

Chatbot renders as an ongoing message thread — bubbles aligned right (user)
and left (assistant), oldest-to-newest top-to-bottom, auto-scrolled to the
latest message on every send. This is deliberately different from how
Insights (Step 7, not yet built) is expected to look: Insights is "ask a
one-off question about your finances" per `ui-ux-mockup-brief.md` §5.11 — a
flat list of independent question/answer pairs, no back-and-forth, no shared
context between entries. Chatbot resends the full prior message list with
every request (the backend keeps no server-side conversation memory — see
`ChatbotApi`), so from the user's point of view it reads as one continuous
conversation, not a log of unrelated queries.

## Response pattern: spinner-then-full-message, not streaming

`backend/app/chatbot/router.py`'s `POST /chat` is synchronous and returns a
complete `ChatResponse` in one round trip — confirmed by reading the router
during blueprint review, not left open for whoever builds this. The UI shows
a single typing-indicator bubble while the request is in flight, then
replaces it with the complete reply. No token-by-token rendering.

## Entry point: Settings, not the Insights tab

Chatbot is pushed from a `GroupRow` in the Settings screen
(`lib/core/router/placeholder_screens.dart`), alongside Subscription,
Security, and Notifications — every other real, gated feature in this app is
surfaced there the same way. The Insights tab was considered and rejected for
now: it is still Step 7's bare "coming soon" `PlaceholderScreen`, with no
actual screen or navigation surface to push from yet. Revisit this decision
once Step 7 gives Insights a real screen — a "chat about this" shortcut from
an Insights answer would be a reasonable addition then, but is not a
substitute for a standalone, discoverable entry point today.

## Paywall handling

Backend gates `POST /chatbot/chat` behind `require_pro_tier` (402 if the
caller is on the free tier). The client makes no separate health/eligibility
check before showing the screen — the Settings row is visible to every user,
and hitting Send is the moment eligibility is actually tested, exactly like
every other paywall-gated action in this app (`accounts_screen.dart`,
`portfolio_sheet.dart`). On a 402, the chat screen pops itself and shows the
same generic `showPaywallPrompt` dialog used elsewhere.
