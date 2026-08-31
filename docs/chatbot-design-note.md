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

## Persona & guardrails (blueprint Step 3, 2026-08-30)

**Chatbot is "Penny"** — named after and voiced as the app's piggy-bank mascot
(the illustrated character used on Login/Create-account per `DESIGN.md`; no
real asset exists yet, this names the *character*, not a new image). Tone is
warm, encouraging, and conversational — a companion the user chats with
regularly — while staying concise, factual, plain-text only (no markdown, no
emoji, no roleplay actions). Implemented in `chat_with_ollama()`,
`piggybank-backend/backend/app/chatbot/service.py`.

**Penny's one teachable habit: "Zoom out first"** (added 2026-08-31, per the
Piggybank competitive-analysis report's finding that a strong AI persona needs
a repeatable principle, not just a warm tone — YNAB's "give every dollar a
job" was the reference point, though Penny's rule is its own, grounded in
Piggybank's actual differentiator). Whenever relevant, Penny connects an
answer back to the user's overall net worth or goal progress from the
snapshot, not just the isolated figure asked about — reinforcing the "all
your wealth in one place" positioning in behavior, not just copy. Skipped
when the question is narrow enough that it would feel forced (e.g. "what
category is this transaction"). Covered by the same deterministic system-
prompt assertion test as the rest of the persona (`test_chatbot.py`'s
`test_chat_system_prompt_has_persona_and_guardrail`, now also asserting
`"Zoom out first"` is present).

**Insights keeps its existing "FinSight" persona but in a clinical register**,
not Penny's — Insights is a one-off, non-conversational "ask a question about
your finances" surface (see layout section above), so it was deliberately
given a different voice: direct, factual, no small talk or encouragement,
same SA-finance-concept grounding and FAIS guardrails as before. This persona
already existed in code (`build_prompt()`,
`piggybank-backend/backend/app/services/ai_context.py`) before this note was
written — the original "no persona direction exists" framing at the top of
this doc was true for the *UI*, not for the AI prompt layer underneath it.

**Shared finance-topic guardrail**: both prompts decline off-topic questions
(general knowledge, coding, entertainment, medical, relationship, or
current-events questions unrelated to money) with the same fixed redirect
sentence — "I can only help with questions about your finances here in
Piggybank." — rather than a bare refusal, per the Step 3 plan's "politely
redirect" requirement. This is enforced entirely at the prompt level (system
prompt content is deterministic and unit-tested — see
`tests/test_chatbot.py::test_chat_system_prompt_has_persona_and_guardrail` and
`tests/test_insights.py::test_prompt_builder_refuses_off_topic_questions`);
whether the live
Ollama model actually *obeys* the guardrail on a given off-topic question is
non-deterministic and was checked manually against the deployed model, not
via an automated test (see `docs/qa/QA_LOG.md` for that transcript once the
backend host is reachable again — blocked this session, see the
launch-readiness plan's Step 3 verification note).
