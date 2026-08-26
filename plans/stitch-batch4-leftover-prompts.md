# Batch 4 — Leftover Stitch Prompts (Imports wizard, Chatbot)

Piggybank Stitch project: `projects/4011413732038259168`
Design system asset: `assets/a4ebed3c029941c992bfc13f8f6565d9`

These are the exact prompts used for `mcp__stitch__generate_screen_from_text` for
the two Batch 4 screens that repeatedly failed to generate (timed out with nothing
queued, or reported "invalid argument", across multiple attempts). Instrument
Comparison, the third Batch 4 screen, generated successfully (with duplicates) and
is not included here.

Both calls used:
- `projectId`: `4011413732038259168`
- `designSystem`: `assets/a4ebed3c029941c992bfc13f8f6565d9`
- `deviceType`: `MOBILE`

---

## Imports wizard

```
Imports wizard screen for a personal finance app. Combines two import paths into one screen: (1) "Scan receipt" — OCR-based receipt scanning, and (2) "Import CSV" — bank/statement CSV upload. Below both entry points, a "Past imports" history list.

Layout, top to bottom:
1. "Scan receipt" section: an icon-chip header, then a dashed-border upload/camera card inviting the user to take a photo or pick an image of a receipt. After a scan, show an OCR review state: a small confidence badge (e.g. "92% confident"), with editable fields for merchant name, amount, date, and category pre-filled from the OCR result, and Confirm/Retry actions.
2. "Import CSV" section: an icon-chip header, then a file-picker card (drag/tap to upload a .csv), a short helper line about supported bank formats, and once a file is chosen, a preview of the first few parsed rows in a themed table before a final "Import" action.
3. "Upload result" section: an icon-chip header, then a themed result/summary card shown after a successful import — number of transactions imported, total imported balance (styled as a prominent money figure with tabular figures), and a "View transactions" link.
4. "Past imports" section: an icon-chip header, then a list of row-cards, each showing an import source icon (receipt or CSV), a filename/merchant label, date, and item count.

Follow the Piggybank design system exactly: Manrope typography, #1F8A4C accent, 20px card radius, pill buttons, circular icon chips in the accent-wash (#E4F5EA) background, tabular figures for all money amounts, calm high-contrast charcoal-on-white base, danger-wash (#FCE8E8) only for error/low-confidence states.
```

---

## Chatbot

```
Chatbot screen for a personal finance app — an AI financial assistant chat thread. Header: a simple top bar with a mascot avatar (small circular icon), title "Financial Assistant" (or similar), and a subtitle like "Ask me anything about your money".

Message thread, top to bottom, mix of message types:
- Bot messages: left-aligned chat bubbles with a small round mascot avatar to the left, bubble background in the accent-wash (#E4F5EA) tint, dark charcoal text, asymmetric corner radii (sharper corner near the avatar, rounder elsewhere) giving a speech-bubble tail feel.
- User messages: right-aligned chat bubbles, solid #1F8A4C accent background, white text, asymmetric corners mirrored to the bot bubbles.
- A "typing" indicator bubble: same style as a bot bubble but containing 3 small animated-looking dots instead of text.
- One bot message should be a rich response containing a small embedded stat card (e.g. "Your spending this month: R4,230" in tabular figures with a small trend arrow) rather than plain text, to show the assistant can surface real financial data inline.
- An error state example: a bot bubble with a muted-danger tint (#FCE8E8 wash) containing a short apologetic error message and a "Retry" link.

Below the thread: a message composer bar pinned to the bottom — a rounded pill-shaped multiline text input with placeholder "Ask about your finances..." and a circular filled send button (accent #1F8A4C background, white paper-plane icon) to its right.

Also design the empty state (shown before any messages exist): centered mascot icon in a circular accent-wash chip, a friendly headline like "Hi, I'm your financial assistant", muted supporting text, and a couple of suggested-question pill chips below (e.g. "How much did I spend on dining?", "Am I on track with my budget?").

Follow the Piggybank design system exactly: Manrope typography, #1F8A4C accent, 20px card radius, pill-shaped composer and buttons, tabular figures for any money figures, calm high-contrast charcoal-on-white base, danger-wash (#FCE8E8) only for the error bubble.
```

---

## Status as of this export

Both prompts were submitted multiple times this session (each call timing out or
erroring client-side); `list_screens` never showed a resulting "Imports" or
"Chatbot" screen after full polling windows (~3-5 min each). Stitch appeared to be
in a genuine outage for new generations at the time. Both screens already have
working, on-brand Flutter implementations from a prior session's fallback
(`lib/features/imports/screens/imports_screen.dart`,
`lib/features/chatbot/screens/chatbot_screen.dart`), so nothing in the app itself
is blocked — only the Stitch design record for these two screens is outstanding.

Re-run these prompts as-is via `mcp__stitch__generate_screen_from_text` (with the
`projectId`/`designSystem`/`deviceType` above) once Stitch is confirmed healthy.
