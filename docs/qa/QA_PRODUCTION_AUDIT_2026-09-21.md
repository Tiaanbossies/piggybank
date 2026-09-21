# Piggybank Production-Readiness Audit (2026-09-21)

Full-app audit using the `flutter-production-audit` skill (static codebase scan + live
Android-emulator walkthrough on the `piggybank` AVD), layered with `ui-ux-pro-max`/`impeccable`
taste-level review, across all 23 feature modules under `lib/features/`. Report-only pass per
plan — one trivial one-line fix was applied incidentally and is noted as such, not logged as an
open finding. All remaining findings feed a separate phased fix-it pass (Stage 2), per this
session's own two-stage instruction.

**Read first, not re-derived:** `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`,
`docs/production-completion-gap-report.md`, `docs/qa/QA_LOG.md`, `DESIGN.md`. Findings already
closed or tracked there (dead-space Low items, filled-avatar icon, green's dual semantic role,
dark mode, seed-data cost-basis bug, AI context excluding account balances) are **not**
re-reported here — see "Still open from prior audits" below for a one-line status check only.

## Top-line summary

| Severity | Count | Theme |
| --- | --- | --- |
| High | 2 | A live backend 500 on the Trends screen; a systemic FAB/list-overlap bug across 8 screens |
| Medium | 4 | Chatbot color/direction mismatch; Dashboard shows finished goals as in-progress; a cramped consent-row layout; truncated destructive/legal text on 3 rows |
| Low | 0 new | (see "still open" section for pre-existing Low items) |
| Fixed inline | 1 | Missing tooltips on two detection-settings delete buttons |

**Baseline confirmed clean:** `flutter analyze` — 0 issues. `flutter test` — 514/514 passing.
16 screens walked live with no debug overflow banners, no crashes, no stale-data mismatches
against the real backend (matches DESIGN.md's specified layout precisely on every screen
checked). Full findings and clean-baseline detail below.

---

## High

### H1. `/summaries/budget-usage` throws a 500 for the two most recent months (backend, not Flutter)

**Where:** `piggybank-backend/backend/app/summaries/router.py:150`, `get_budget_usage`.
**Found via:** live walkthrough — Home → Trends → "Budget adherence" rendered
`Internal server error`. Reproduced directly: `GET /summaries/budget-usage?month=2026-09` → 500
(`?month=2026-08` also 500; April–July all 200).
**Root cause (confirmed precisely, not just from the traceback):**
```
sqlalchemy.exc.MultipleResultsFound: Multiple rows were found when one or none was required
  File "/app/app/summaries/router.py", line 150, in get_budget_usage
    ).scalar_one_or_none()
```
`get_budget_usage`'s query (`summaries/router.py:145-150`) filters only on `Budget.user_id` and
`Budget.month`, with **no `Budget.parent_budget_id.is_(None)` filter** — so it matches the
top-level `Budget` row *and* any of that month's sub-category child rows at once. The sibling
query in `budgets/router.py:217` already guards against exactly this with
`Budget.parent_budget_id.is_(None)`; `get_budget_usage` never picked up the same guard. This is a
real production risk for any user with sub-budget categories for a given month — a normal,
DESIGN.md-encouraged pattern ("Sub-categories render as indented progress cards within their
parent's group"), not a demo-data-only edge case. *(Correction, logged 2026-09-21 during Stage 2
planning: this report originally attributed the crash to "duplicate Budget rows from repeated
seed runs" — a plausible-sounding but incorrect guess. The observable symptom, the 500, and the
traceback are unchanged; only the root-cause narrative above has been corrected after reading the
actual query.)*
**Not fixed here** — backend change, out of this Flutter-focused audit's scope. See
`plans/piggybank-production-audit-2026-09-21-fixit.md` Phase 1 for the fix (add the same
`parent_budget_id.is_(None)` filter already used elsewhere in this codebase).

### H2. `FloatingActionButton` overlaps and obscures list content on 8 screens

**Where:** `accounts_screen.dart` (a `SingleChildScrollView`, not a `ListView` — same missing
bottom-clearance bug, different scroll widget), `assets_screen.dart`, `budgets_screen.dart` (the
actual `BudgetsBody`/`GoalsBody` list widgets — **not** `budgets_home_screen.dart`, which only
holds the segmented control + the FAB itself), `liabilities_screen.dart`,
`liability_detail_screen.dart`, `portfolio_detail_screen.dart`, `ra_ledger_screen.dart`,
`tfsa_ledger_screen.dart`. Each uses a flat `padding: const EdgeInsets.all(16)` on its scrollable
body alongside a `FloatingActionButton.extended`, with no extra bottom clearance for the FAB's
own footprint. *(Correction, logged 2026-09-21 during Stage 2 planning: this report originally
listed 9 files including `transactions_screen.dart` and misidentified `accounts_screen.dart`/
`budgets_home_screen.dart`'s actual widget shape. `transactions_screen.dart` was already fixed —
it defines `_kFabClearance = 88` and applies `EdgeInsets.fromLTRB(16, 16, 16, 16 +
_kFabClearance)`, citing the 2026-09-11 audit — and is excluded from the corrected list above.
`accounts_screen.dart` uses `SingleChildScrollView`, not `ListView`; the actual Budgets list body
lives in `budgets_screen.dart`, not `budgets_home_screen.dart`. Verified by direct file
inspection, not re-derived from the original grep pass.)*
**Found via:** live walkthrough, confirmed on 4 separate screens:
- Portfolio Detail: "Add holding" FAB covers SBK.JO's subtitle and day-change %.
- Budgets: "Add budget" FAB covers the Transport category row.
- Assets: "Add asset" FAB fully covers the second "Personal Laptop" row's title.
- Accounts: "Add account" FAB covers part of the "Accounts overview" stat card.
- Transactions: "Add transaction" FAB covers the Monthly salary row and the next date header.
**Why it matters:** every one of these lists grows with normal use (more accounts, more
transactions, more holdings) — this isn't an edge case, it's the expected end state for an
active user on 8 of the app's most-used screens.
**Suggested fix (not applied — needs a UX call, not a blind one-liner):** reuse
`transactions_screen.dart`'s existing `_kFabClearance = 88` constant and
`EdgeInsets.fromLTRB(16, 16, 16, 16 + _kFabClearance)` pattern across the remaining 8 screens,
rather than inventing a second clearance value. This screen already solved the exact same problem
once; the fix just never propagated to its siblings.

---

## Medium

### M1. Chatbot's inline stat-card reply always renders its trend color as "success," regardless of direction

**Where:** `lib/features/chatbot/screens/chatbot_screen.dart:297-349`, `_StatCardReply`,
matched via `_statCardPattern` (line 212).
**What's wrong:** `isDown` is correctly computed from the regex-captured direction
(`lower|down|less` vs `higher|up|more`) and used to pick between `Icons.trending_down` /
`Icons.trending_up` — but the color for both the icon and the percentage text is hardcoded to
`semantic?.success` (green) in both branches. A reply like "spending is 12% higher" would show a
correctly-upward green icon, but so would "portfolio value is 12% lower" — always green,
regardless of whether "down" is good or bad news for that particular figure.
**Why it matters:** contradicts the app's own established convention elsewhere — DESIGN.md's
Portfolio Detail spec explicitly calls out "day-change... green if up, red if down" as "the one
place a red/green duality on ordinary figures is appropriate." This widget silently drops that
convention for AI-sourced figures.
**Not a trivial fix:** the regex has no way to know whether "down" is good (spending) or bad
(portfolio value) for a given reply, so a blind icon-color flip could just as easily introduce a
wrong-polarity bug in the other direction. Needs a product decision — e.g. classify by keyword
("spending"/"expenses" vs "value"/"balance"/"portfolio"), or drop the color-coding for this
widget entirely and rely on the icon alone.

### M2. Dashboard's "most relevant" progress card doesn't recognize a completed goal

**Where:** `lib/features/dashboard/screens/dashboard_screen.dart:301-338`, `_ProgressBlock`.
**What's wrong:** picks `goals.first` and renders it through the generic `ProgressCard` (percent
pill + progress bar) unconditionally — it never checks for a 100%-complete goal, unlike
`goals_screen.dart:121`, which explicitly swaps in a "Goal complete!" + mascot treatment for the
identical condition.
**Found via:** live walkthrough — the "New Laptop" goal (100%, fully saved) renders as a plain
"100%" progress card on the Dashboard, but as a celebratory "Goal complete!" card with mascot
art on the Goals screen, for the exact same underlying data.
**Why it matters:** a finished goal can sit on the home screen indefinitely, visually
indistinguishable from an in-progress one — the app's own celebratory pattern exists but isn't
reused where a user would actually see it first.

### M3. "Feature consent" row wraps awkwardly on the Notification & email detection screen

**Where:** `lib/features/detection/screens/detection_settings_screen.dart:239-244` — a standard
`ListTile` with `title: 'Feature consent'`, `subtitle: 'Not yet accepted'`, and
`trailing: ElevatedButton(child: Text('Review & enable'))`.
**What's wrong:** the wide trailing button squeezes `ListTile`'s title/subtitle column into a
narrow strip, wrapping to 4 lines ("Feature / consent / Not yet / accepted") instead of reading
as two short lines.
**Why it matters:** this is the entry-point row for the whole feature — the first thing a user
sees on this screen reads as visually broken, even though nothing is functionally wrong.
**Not fixed here:** needs a layout restructure (e.g. button below the text instead of beside it,
or a shorter button label), not a one-line change.

### M4. Destructive-action and legal-disclosure row subtitles get truncated to one line, in 3 places

**Where:** `lib/shared/widgets/group_card.dart:79-86` hardcodes `maxLines: 1` on the subtitle
(line 76's `maxLines: 1` is the separate *title* field) /
`TextOverflow.ellipsis` on its subtitle. This is the right choice for the short labels it's used
for almost everywhere (account institution names, transaction categories) — but three specific
rows reuse it for genuinely longer descriptive text:
- Security screen: "Delete my account" → *"Permanently erase your account and all your…"*
  (`security_screen.dart:195-196`)
- Privacy & consent: "Privacy Policy" → *"How we collect, store, and use your p…"*
- Privacy & consent: "Terms of Service" → *"The rules and conditions for using Fi…"*
**Why it matters:** two of the three are describing a destructive or legally-relevant action —
truncating exactly the sentence that explains the consequence is a worse trade-off here than it
is for a transaction category label.
**Not a `GroupCard` bug** — don't widen the component's default for every other caller. These
three call sites should either shorten their copy to fit one line, or opt into a longer-subtitle
variant if the pattern recurs elsewhere.

---

## Fixed inline (trivial, per audit convention)

### F1. Two delete `IconButton`s missing tooltips — `detection_settings_screen.dart`

The 2026-09-11 audit confirmed *every* `IconButton` in the codebase had a tooltip (a full-app
grep returned zero exceptions). `detection_settings_screen.dart`, built after that audit
(Phase D, merged 2026-09-15), broke that invariant with two `delete_outline` buttons (remove
notification-app source, remove email source) that had none. Added `tooltip: 'Remove app'` and
`tooltip: 'Remove sender'` respectively — a genuinely trivial, single-file, zero-behavior-change
fix. `flutter analyze` re-run clean afterward (0 issues).

---

## Still open from prior audits (not re-reported as new)

- **L1 (dead space on short-content screens)** — still present and unaddressed on Notifications,
  Subscription, Calculators, and now also About (a 4th instance, same pattern, not a new
  finding). Confirmed live this session.
- **Seed-data cost-basis bug** (per-unit vs total) — still visible on Invest (unrealized P&L
  shows -R139,875.29 against an R87,124.71 portfolio value), consistent with the previously
  diagnosed seed-script defect. Confirmed still a demo-data issue, not re-diagnosed as new.
- **AI context excludes account/portfolio balances** — not independently re-verified this
  session (out of scope for a UI/UX audit), flagged only as still-relevant context for anyone
  picking up H1 above, since both live in the same `summaries`/AI-context code paths.

---

## Confirmed clean / production-grade

- **Static baseline:** `flutter analyze` 0 issues, `flutter test` 514/514 passing, both re-run
  clean after this session's one inline fix.
- **No unbounded-list anti-pattern:** every non-`.builder` `ListView` usage found (31 call
  sites) is either an empty-state placeholder or a small, inherently-bounded per-user collection
  (assets, liabilities, goals) rendered via a `for` comprehension inside one `GroupCard` —
  `transactions_screen.dart` correctly uses `ListView.builder` for its genuinely large, grouped
  list, by explicit design comment.
- **No `Image.network` usage anywhere** — no remote-image caching concern exists in this app.
- **Every `AnimationController` has a matching `dispose()`.**
- **Dio client has both `connectTimeout` (8s) and `receiveTimeout` (15s) configured** — no
  unbounded network hang possible.
- **Currency formatting is centralized** through `formatZAR`/`moneyTextStyle` — no bypasses
  found outside legitimate non-currency numeric displays (Sharpe ratio, percentages).
- **SafeArea coverage complete** — no screen with a bare `Scaffold` lacking `SafeArea` found.
- **Liabilities' conditional progress bar** (shown for loans/mortgages, correctly omitted for
  the credit card, which has no fixed payoff term) is a deliberate, sensible distinction, not an
  inconsistency.
- **16 screens walked live with zero debug overflow banners, zero crashes:** Login, Dashboard,
  Invest, Portfolio Detail, Chatbot/Assistant (including a real Ollama round-trip), all 8
  Settings sub-screens, Budgets, Goals, Trends, Detection Settings, Accounts, Liabilities,
  Transactions, Assets, Calculators — every one matched DESIGN.md's specified layout precisely
  where a spec exists.
- **Transactions screen's 3 app-bar icon buttons** (filter, expenses summary, import) all have
  tooltips — confirms F1's regression was isolated, not a broader tooltip gap.
- **App version confirmed live:** About screen shows 1.0.3 (4), matching the latest commit at
  audit time.

---

## Recommended next step

H1 (backend 500) and H2 (FAB overlap, 8 screens) are the two items worth prioritizing in Stage
2's phased fix plan — H1 for correctness/reliability risk, H2 for breadth of impact. M1-M4 are
real but lower-urgency polish items, each needing a small product/design decision rather than a
blind mechanical fix.
