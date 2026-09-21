# Blueprint: Fix findings from the 2026-09-21 production audit

**Source report:** `docs/qa/QA_PRODUCTION_AUDIT_2026-09-21.md` (Stage 1, report-only). This plan
is Stage 2 — turning that report's 6 remaining findings (2 High, 4 Medium) into a phased fix.
Already fixed and committed in Stage 1, not replanned here: two missing `IconButton` tooltips in
`detection_settings_screen.dart` (commit `d00142e`).

**Mode:** git is available in both repos; GitHub CLI (`gh`) is **not installed** in this
environment, and pushing to a remote requires explicit user approval per this session's own
permission gate (confirmed: a `git push` was denied this session). Each phase below still uses
its own local branch, matching this repo's established convention (`detection-phase-a/b/c/d/e`),
but **PR creation and pushing are left to the user** — a phase's "done" state is a clean local
commit on its own branch, verified, ready for the user to push/PR when they choose.

**Repos involved:**
- `Piggybank` (this repo, Flutter) — `C:\Fynbos Creative Master\02_Clients\Piggybank`, branch
  `master`.
- `piggybank-backend` (FastAPI) — `C:\Fynbos Creative Master\02_Clients\piggybank-backend`,
  branch `main`. **Different default branch name than this repo** — don't assume `master`.

**Ordering:** all 6 phases are mutually independent (no shared files between any two) and can run
in any order, including in parallel across sessions. Suggested order below is by
severity/breadth, not dependency.

---

## Phase 1 — Backend: fix duplicate-budget-row crash (H1)

**Repo:** `piggybank-backend`. **Branch:** `audit-h1-budget-usage-dedup`, off `main`.
**Model tier:** default (Sonnet) is sufficient — this is a scoped bug fix with a clear repro, not
an architecture decision.

**Context brief (self-contained — no need to re-read the audit report; root cause confirmed
precisely during Stage 2 planning, corrected from Stage 1's original guess):**
`backend/app/summaries/router.py:145-150`, `get_budget_usage`, runs:
```python
budget = db.execute(
    select(Budget).where(
        Budget.user_id == current_user.id,
        Budget.month == first_of_month,
    )
).scalar_one_or_none()
```
This filters only on `user_id` and `month` — it has **no `Budget.parent_budget_id.is_(None)`
filter** — so for a month where the user has both a top-level budget row and one or more
sub-category child rows (a normal pattern: `Budget` is parent/child via `parent_budget_id`, and
DESIGN.md explicitly documents sub-category budgets as a supported UI pattern), the query matches
more than one row and `.scalar_one_or_none()` raises `MultipleResultsFound` → 500. The sibling
query in `backend/app/budgets/router.py:217` already guards against exactly this:
```python
select(Budget.month, func.coalesce(func.sum(Budget.total_budget), Decimal("0")))
.where(
    Budget.user_id == current_user.id,
    Budget.month.in_(month_starts),
    Budget.parent_budget_id.is_(None),
)
```
`get_budget_usage` simply never picked up the same guard. This breaks the Flutter app's Trends
screen ("Budget adherence" section) for any month where the user has sub-budgets — a real risk
for any real user using a documented, encouraged feature, not just this demo account's seed data.

**Task list:**
1. Read `backend/app/models.py`'s `Budget` model (confirm the `parent_budget_id` column and its
   semantics) and both `get_budget_usage` (`summaries/router.py:138-150`) and the working
   precedent in `budgets/router.py:210-220` in full before changing anything.
2. Add `Budget.parent_budget_id.is_(None)` to `get_budget_usage`'s `.where()` clause, matching
   the existing precedent exactly — this is not a judgment call, it's applying the same guard the
   codebase already established elsewhere for the identical query shape.
3. Grep `summaries/router.py` and `budgets/router.py` for every other `select(Budget)` /
   `select(...Budget...)` call and confirm each one either already has the
   `parent_budget_id.is_(None)` guard where it needs one, or is intentionally querying child rows
   (e.g. a sub-category-specific lookup) — fix any other instance of the same missing-guard bug
   found, don't stop at the one reported line if the mistake is copy-pasted elsewhere.
4. Add a regression test in `backend/tests/` (check for an existing
   `test_summaries.py`/`test_budget_usage.py` and extend it, or create one following this repo's
   existing test-file conventions) that seeds a top-level `Budget` row **and** a child row with
   `parent_budget_id` set, for the same user/month, and asserts `GET /summaries/budget-usage`
   returns 200 (using the top-level row's `total_budget`), not a 500.

**Verification (must all pass before this phase is done):**
```bash
cd backend
pytest                          # full suite green, including the new regression test
ruff check .                    # clean
```
Then, against the **real production backend** (`100.121.165.7`, matching how the audit found
this bug), confirm the fix actually closes the gap — this is a live system, code-review alone is
not sufficient proof:
1. Deploy is a separate, explicit decision — do **not** deploy to production as part of this
   phase without the user's go-ahead (this phase's exit criterion is a verified local fix, not a
   production deploy).
2. If the user approves a deploy: `ssh mcp@100.121.165.7 && cd ~/piggybank-backend && git pull
   && docker compose --env-file .env.docker up -d --build`, then re-run
   `GET /summaries/budget-usage?month=2026-09` (and `2026-08`) with the demo account's token and
   confirm `200`, not `500`.

**Exit criteria:** `pytest` and `ruff` clean, new regression test passing, fix committed on
`audit-h1-budget-usage-dedup`. Production verification deferred to a separate, explicitly
user-approved deploy step (do not bundle a production deploy into this phase silently).

**Rollback:** `git checkout main` (nothing merged yet — this phase never touches `main` directly).

---

## Phase 2 — Flutter: fix FAB overlapping list content on 8 screens (H2)

**Repo:** `Piggybank`. **Branch:** `audit-h2-fab-list-clearance`, off `master`.
**Model tier:** default (Sonnet).

**Context brief (corrected during Stage 2 planning — the Stage 1 report originally named 9
files, including one already fixed and two with the wrong shape; verified by direct file
inspection, not re-derived from the original grep pass):**
`lib/features/transactions/screens/transactions_screen.dart` **already solved this exact
problem** (fixed per the 2026-09-11 audit): it defines
```dart
static const double _kFabClearance = 88;
```
and applies `padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + _kFabClearance)` to its lists.
That fix never propagated to 8 sibling screens with the identical bug — a flat
`padding: const EdgeInsets.all(16)` on the scrollable body, no bottom clearance for the
`FloatingActionButton.extended` sitting on top of it:
- `lib/features/accounts/screens/accounts_screen.dart` — **`SingleChildScrollView`, not
  `ListView`** (line 60-61); same missing-clearance bug, different scroll widget.
- `lib/features/assets/screens/assets_screen.dart` — `ListView` (two instances, lines 45-46 and
  51-52).
- `lib/features/budgets/screens/budgets_screen.dart` — **not** `budgets_home_screen.dart` (which
  only holds the segmented Budgets/Goals control and the FAB itself) — the actual list widgets
  (`ListView`, two instances, lines 75-77 and 87-89) live here.
- `lib/features/liabilities/screens/liabilities_screen.dart` — `ListView` (two instances, lines
  58-59 and 64-65).
- `lib/features/liabilities/screens/liability_detail_screen.dart` — `ListView` (line 55-56).
- `lib/features/portfolios/screens/portfolio_detail_screen.dart` — `ListView` (line 79-80) —
  confirmed live in the Stage 1 audit (SBK.JO row obscured).
- `lib/features/ra/screens/ra_ledger_screen.dart` — `ListView.builder` (line 65-66).
- `lib/features/tfsa/screens/tfsa_ledger_screen.dart` — `ListView.builder` (line 64-65).

**Task list:**
1. Reuse `transactions_screen.dart`'s exact pattern — `_kFabClearance = 88` and
   `EdgeInsets.fromLTRB(16, 16, 16, 16 + _kFabClearance)` — on all 8 files above. This is not a
   design decision to make fresh; it's propagating an already-established, already-tested fix.
   Either duplicate the constant in each file (matching this repo's own stated precedent of
   duplicating small helpers rather than sharing them — see `piggybank-backend`'s
   `_validate_ollama_url` convention, though that's the other repo; check whether this repo has
   an equivalent "shared const in a common file" pattern before deciding, and default to
   duplicating the constant per-file if no such shared-constants file already exists) or add it
   to a shared location if one obviously fits (e.g. an existing `lib/core/theme/` or
   `lib/shared/` constants file) — don't invent a new shared-constants file just for this.
2. For `accounts_screen.dart`'s `SingleChildScrollView`, apply the same
   `EdgeInsets.fromLTRB(16, 16, 16, 16 + _kFabClearance)` padding — the fix is identical in shape
   even though the scroll widget differs.
3. Apply the same padding change to the two `ListView`s in `budgets_screen.dart` (both the
   Budgets and Goals list bodies) — confirm both call sites, don't fix only one and miss the
   other.
4. For each of the remaining 5 files, apply the same padding change to their single `ListView`/
   `ListView.builder` instance.

**Verification:**
```bash
flutter analyze     # 0 issues (matches current clean baseline)
flutter test         # 514/514 passing (matches current baseline) — confirm no regression
```
Then a **live re-check** on the `piggybank` AVD (the whole point of this phase — a padding number
that looks right in code can still be wrong on a real screen):
1. Boot the emulator, install a debug build, log in as the demo account
   (`demo@financeapp.co.za` / `Demo@1234!`).
2. Re-visit the screens the Stage 1 audit confirmed the overlap on live (Portfolio Detail →
   Growth Portfolio, Budgets, Assets, Accounts) and screenshot each, confirming the
   previously-obscured row/text is now fully visible above the FAB.
3. Spot-check at least 2 of the remaining screens not directly confirmed live in Stage 1
   (`liabilities_screen.dart`, `ra_ledger_screen.dart`, `tfsa_ledger_screen.dart`,
   `liability_detail_screen.dart`) to confirm the fix applies cleanly there too, not just where
   the bug was originally observed.
4. Re-visit `transactions_screen.dart` too and confirm it's visually unchanged (this phase must
   not touch its already-working fix).

**Exit criteria:** `flutter analyze`/`flutter test` clean, live re-check screenshots confirm the
FAB no longer covers list content on all spot-checked screens, `transactions_screen.dart`
unmodified, committed on `audit-h2-fab-list-clearance`.

**Rollback:** `git checkout master` (nothing merged yet).

---

## Phase 3 — Flutter: Dashboard shows a completed goal without the "complete" treatment (M2)

**Repo:** `Piggybank`. **Branch:** `audit-m2-dashboard-goal-complete`, off `master`.
**Model tier:** default (Sonnet).

**Context brief:** `lib/features/dashboard/screens/dashboard_screen.dart:301-338`,
`_ProgressBlock`, picks `goals.first` and renders it through the generic `ProgressCard`
unconditionally. `lib/features/goals/screens/goals_screen.dart` (around line 121) already has a
"Goal complete!" + mascot treatment for a 100%-complete goal that `_ProgressBlock` never checks
for or reuses.

**Task list:**
1. Read `goals_screen.dart`'s completed-goal branch in full (the exact widget tree, not just the
   text) — understand what visual treatment exists before deciding how to reuse it.
2. Decide: extract the completed-goal treatment into a small shared widget both
   `goals_screen.dart` and `dashboard_screen.dart` can use, or duplicate the minimal rendering
   logic into `_ProgressBlock` directly. Prefer extraction if the completed-goal widget in
   `goals_screen.dart` is self-contained and not entangled with Goals-screen-specific state;
   duplicate only if extraction would require a disproportionate refactor for a small UI check.
3. Update `_ProgressBlock` in `dashboard_screen.dart` to check `goal.progressPct >= 100` (or
   whatever the actual completed-goal condition is in `goals_screen.dart` — verify the exact
   condition rather than assuming `>= 100`) and render the completed treatment when true.
4. Consider (flag in the PR description, don't silently decide) whether a completed goal should
   still be `goals.first` at all on the Dashboard — i.e. should the "most relevant" goal selection
   logic prefer an *incomplete* goal over a complete one, so the home screen surfaces something
   actionable rather than a completed item? This is a product question the audit didn't resolve;
   implement the minimal "show the complete treatment when it is shown" fix first, and note the
   selection-logic question as a follow-up rather than scope-creeping into it here.

**Verification:**
```bash
flutter analyze
flutter test
```
Add a widget test for `_ProgressBlock` (or `dashboard_screen.dart`'s existing test file, if one
exists — check `test/features/dashboard/` first) covering: a 100%-complete goal renders the
completed treatment; an in-progress goal still renders the normal `ProgressCard`. Then a live
re-check: log in as the demo account, confirm the Dashboard's "New Laptop" card now matches the
Goals screen's "Goal complete!" treatment.

**Exit criteria:** analyze/test clean, new widget test passing, live screenshot shows matching
treatment between Dashboard and Goals screen, committed on `audit-m2-dashboard-goal-complete`.

**Rollback:** `git checkout master`.

---

## Phase 4 — Flutter: chatbot stat-card color should reflect whether "down" is good or bad (M1)

**Repo:** `Piggybank`. **Branch:** `audit-m1-chatbot-statcard-direction`, off `master`.
**Model tier:** default (Sonnet) for implementation, but **this phase has an unresolved product
decision the audit explicitly flagged — surface it to the user before implementing, don't guess.**

**Context brief:** `lib/features/chatbot/screens/chatbot_screen.dart:297-349`, `_StatCardReply`,
parses a free-form AI reply via `_statCardPattern` (line 212) for a label/amount/percentage/
direction, and always colors the icon+percentage `semantic?.success` (green) regardless of
whether the parsed direction is up or down. DESIGN.md's own convention elsewhere is "green if up,
red if down" for price movement — but this widget can't tell from the regex alone whether "down"
is good news (e.g. "spending is 12% lower") or bad news (e.g. "portfolio value is 12% lower") for
a given reply.

**Task list — decision gate first:**
1. **Before writing any code**, ask the user (or, if working autonomously with no user
   available, default to the conservative option below and flag it clearly in the PR
   description): should this widget (a) classify direction-is-good-or-bad by keyword matching on
   the parsed `label` (e.g. "spending"/"expenses" → down-is-good; "value"/"balance"/"portfolio"
   → down-is-bad), or (b) drop color-coding for this widget entirely and rely on the
   up/down icon alone (no red/green), sidestepping the ambiguity?
2. **Conservative default if no answer available:** implement (b) — remove the
   `semantic?.success` hardcoding and render the icon in a neutral color (e.g.
   `semantic?.textMuted` or the same on-surface color as the rest of the card), keeping only the
   directional icon (`trending_up`/`trending_down`) as the signal. This never introduces a
   wrong-polarity bug, unlike a keyword-classification heuristic that could misfire on an
   ambiguous label.
3. If the user does want keyword classification (option a), implement it as a small pure
   function (e.g. `bool _isPositiveDirection(String label, bool isDown)`) with unit tests covering
   at least: a spending/expense label (down=good), a value/balance/portfolio label (down=bad), and
   an unrecognized label (fall back to the neutral/no-color treatment from option b, never guess).

**Verification:**
```bash
flutter analyze
flutter test
```
Add/extend a widget test for `_StatCardReply` covering the chosen behavior. Live re-check: ask
Penny a question likely to trigger the stat-card pattern (a percentage-comparison question) and
confirm the rendered color matches the chosen policy — note in the PR that the real Ollama model
doesn't reliably produce this exact response shape on demand (confirmed during the Stage 1 audit
via several attempts), so this live check may need multiple tries or a temporarily-mocked
response to actually exercise the widget.

**Exit criteria:** decision recorded in the PR description (not silently made), analyze/test
clean, new/updated widget test passing, committed on `audit-m1-chatbot-statcard-direction`.

**Rollback:** `git checkout master`.

---

## Phase 5 — Flutter: "Feature consent" row layout fix (M3)

**Repo:** `Piggybank`. **Branch:** `audit-m3-detection-consent-row-layout`, off `master`.
**Model tier:** default (Sonnet).

**Context brief:** `lib/features/detection/screens/detection_settings_screen.dart:238-245` — a
`ListTile` inside a `Card`, with `title: const Text('Feature consent')`,
`subtitle: Text(_consentAccepted ? 'Accepted' : 'Not yet accepted')`, and a conditional
`trailing: _consentAccepted ? null : ElevatedButton(child: Text('Review & enable'))`. The wrap
issue only manifests in the unaccepted state (the state the audit screenshotted) — once
`_consentAccepted` is true, `trailing` is `null` and the row already reads fine on one line.

**Task list:**
1. Re-read the surrounding widget tree (lines ~230-250) to confirm the `Card` wrapper and the
   conditional structure above before changing anything.
2. Restructure the **unaccepted-state** rendering so the button doesn't compete with the text for
   horizontal space — the simplest
   fix is a `Column` with the icon+title+subtitle on one row and the button on its own row below
   (matching the pattern likely already used elsewhere in Settings for a similar
   status-plus-action row — check `subscription_screen.dart` or `security_screen.dart` for a
   precedent before inventing a new layout shape).
3. Keep the icon (`Icons.check_circle_outline` / `Icons.privacy_tip_outlined`, conditional on
   `_consentAccepted`) and the button's `onPressed: _acceptConsent` behavior unchanged — this is a
   layout-only fix, not a behavior change.

**Verification:**
```bash
flutter analyze
flutter test
```
Live re-check: navigate to Settings → Notification & email detection, screenshot, confirm the
title/subtitle now reads on 1-2 lines instead of 4, with the button clearly separated.

**Exit criteria:** analyze/test clean, live screenshot confirms the fix, committed on
`audit-m3-detection-consent-row-layout`.

**Rollback:** `git checkout master`.

---

## Phase 6 — Flutter: truncated destructive/legal subtitle text, 3 call sites (M4)

**Repo:** `Piggybank`. **Branch:** `audit-m4-truncated-subtitle-copy`, off `master`.
**Model tier:** default (Sonnet).

**Context brief:** `lib/shared/widgets/group_card.dart:79-86` hardcodes `maxLines: 1` on its
subtitle (line 76's `maxLines: 1` is the separate *title* field, not the one at issue here) —
correct for the short labels used almost everywhere, but 3 specific call sites reuse
it for longer descriptive text that gets cut off: `lib/features/settings/screens/
security_screen.dart:195-196` ("Delete my account" → "Permanently erase your account and all
your…"), and two rows on the Privacy & consent screen (find the exact file — likely
`lib/features/consent/` or a settings sub-screen; verify rather than assume the path) for
"Privacy Policy" and "Terms of Service".

**Task list:**
1. Locate all 3 call sites precisely (the audit report names the visible truncated text but not
   necessarily every file path — confirm each one, e.g. via `grep -rn "Privacy Policy" lib/` and
   `grep -rn "Terms of Service" lib/`).
2. **Do not change `group_card.dart`'s default** — every other caller relies on the 1-line
   truncation behavior; changing the shared component would be a much larger, riskier change than
   this finding calls for.
3. For each of the 3 call sites, choose per-row: shorten the subtitle copy to fit cleanly on one
   line (preferred — keeps the existing component untouched), or, only if shortening would lose
   meaningfully important information, build that one row without going through `GroupCard`'s
   single-line subtitle (e.g. a custom `ListTile`/`Column` with `maxLines: 2` for that specific
   row only). Prefer the copy-shortening fix for at least the two Privacy & consent rows (they're
   summaries linking to a full document, so brevity is natural there); the "Delete my account"
   row's consequence text is the stronger candidate for a 2-line layout instead, since shortening
   a destructive-action warning is a worse trade-off than shortening a document-summary blurb.

**Verification:**
```bash
flutter analyze
flutter test
```
Live re-check: Settings → Security (confirm "Delete my account" subtitle is no longer cut off
mid-sentence) and Settings → Privacy & consent (confirm both rows read fully).

**Exit criteria:** analyze/test clean, live screenshots confirm all 3 rows read completely,
`group_card.dart` itself unchanged, committed on `audit-m4-truncated-subtitle-copy`.

**Rollback:** `git checkout master`.

---

## Summary

| Phase | Repo | Branch | Severity | Decision gate? |
|---|---|---|---|---|
| 1 | piggybank-backend | `audit-h1-budget-usage-dedup` | High | No (apply existing `parent_budget_id.is_(None)` precedent) |
| 2 | Piggybank | `audit-h2-fab-list-clearance` | High | No (reuse existing `_kFabClearance = 88` precedent) |
| 3 | Piggybank | `audit-m2-dashboard-goal-complete` | Medium | No (implementation choice only) |
| 4 | Piggybank | `audit-m1-chatbot-statcard-direction` | Medium | **Yes — needs user input, has a safe default** |
| 5 | Piggybank | `audit-m3-detection-consent-row-layout` | Medium | No |
| 6 | Piggybank | `audit-m4-truncated-subtitle-copy` | Medium | No |

All 6 phases are independent and can be executed in any order, by any number of parallel
sessions/agents, since none share a file. None of them include a production deploy or a `git
push`/PR creation step — those remain explicit, separate, user-approved actions per phase, not
bundled into "done."
