# Blueprint: Fix findings from `docs/qa/QA_PRODUCTION_AUDIT_2026-09-11.md`

**Objective:** Close every finding from the 2026-09-11 production-readiness audit (7 findings —
0 Critical, 0 High, 4 Medium, 3 Low — plus 1 regression re-test and 2 unlogged trivial lints).
This is a **fix-it** plan, not another audit: every item here already has a confirmed repro and a
file:line citation in the source report. Nothing needs re-discovering, only fixing and
re-verifying.

**Mode:** Git branches + manual PR (no `gh` CLI on this machine — confirmed via `which gh` →
not found). `Piggybank` has a real `origin` remote (`https://github.com/Tiaanbossies/piggybank.git`,
default branch `master`) — push each branch and open the PR manually via the browser link Git
prints after `git push`, matching how PRs #1-#4 were created in the prior lock-screen/APK-pipeline
session.

`piggybank-backend` **does** have a PR-based CI gate now (`.github/workflows/deploy.yml`: `ruff` +
`pytest` run on any PR opened against `main`), but this team's established practice (confirmed via
`docs/runbook.md` and prior sessions) is still to commit straight to `main` rather than open PRs
there — a direct push to `main` runs the same `backend-ci` job via the workflow's `push` trigger,
so nothing is skipped either way. **Corrected deploy story (adversarially reviewed — the original
draft of this plan had this backwards):** as of `docs/runbook.md`'s 2026-09-06 update, `git pull`
on the server is the *authoritative* deploy path (the `mcp` user has its own read-only GitHub
deploy key) — **not** tar+scp, which is now explicitly the fallback ("use only if the server's
GitHub access is broken"). Separately, `.github/workflows/deploy.yml` also has an automated
`deploy` job gated on `push` to `main` that SSHes into the server itself — per `docs/runbook.md`,
this automated path is described as "not in use" as of that doc's writing, so **do not assume a
push to `main` alone ships the change** — confirm which path is actually live (check whether the
`deploy` job in GitHub Actions actually ran and succeeded after Step 6's push) before treating R1
as deployed, and fall back to the manual `git pull` steps in `docs/runbook.md` if the Actions
deploy job didn't fire or failed.

**Source of truth for every step below:** `docs/qa/QA_PRODUCTION_AUDIT_2026-09-11.md` — read the
cited section there for full repro detail; this plan's task lists summarize, they don't replace it.

**Grounded against the live files before drafting (2026-09-11):**
- `lib/features/transactions/screens/transactions_screen.dart` — confirmed the `ListView(children:
  [...])` pattern at the "no transactions" early-return (~line 87) and the main list build
  (~line 96), and the `FloatingActionButton.extended` at ~line 127 with no matching bottom padding
  on either `ListView`.
- `lib/core/auth/auth_api.dart:20-21` — confirmed `AuthApi({Dio? dio}) : _dio = dio ??
  Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));`, no timeout options set, with a doc comment
  explaining *why* it's a separate Dio instance (avoids a circular dependency with `ApiClient`'s
  refresh interceptor) — Step 3 must preserve that separation, not merge the two clients.
- `lib/core/api/api_client.dart:27-31` — confirmed the exact pattern to mirror: `connectTimeout:
  Duration(seconds: 8)`, `sendTimeout`/`receiveTimeout: Duration(seconds: 15)`, plus a comment
  already referencing "fix-it plan Step 3 / QA H6" as the pattern's origin — Step 3 below should
  reference this same convention rather than inventing new timeout values.

**Pre-flight (before Step 1 — do this once, not per-step):** `git status --short` in `Piggybank`
currently shows uncommitted changes: `QA_FINDINGS.md` (modified — it already has a **2026-09-11**
dated "Update" section prepended, written by the audit itself, describing these same 7 findings)
plus two untracked files (`docs/qa/QA_PRODUCTION_AUDIT_2026-09-11.md` itself, and unrelated
`plans/stitch-batch5-prompts.md` + `qa_screens/` from other work). Commit this dirty state to
`master` first (`git add QA_FINDINGS.md docs/qa/QA_PRODUCTION_AUDIT_2026-09-11.md qa_screens/
plans/stitch-batch5-prompts.md && git commit`) before branching for Step 1 — otherwise every
step's branch inherits these uncommitted changes and Step 7's `QA_FINDINGS.md` edit will conflict
with or duplicate the section that's already there.

**Explicitly out of scope:**
- Re-running the audit itself, or re-verifying any of the "Confirmed clean" section's items —
  they're closed, not part of this plan.
- Any deeper refactor beyond what each finding's own "fix direction" implies (e.g. M2/L1 is a
  `.builder` conversion, not a pagination-architecture rewrite).
- L3 may turn out to need no fix at all (a legitimate two-lot holding) — that's a valid, complete
  outcome for that step, not a blocker on the rest of the plan.

---

## Dependency graph

```
Step 1 (Transactions screen: FAB padding + ListView.builder)   ─┐
Step 3 (AuthApi timeout)                                        ├─ independent, run in parallel
Step 5 (L3: GLD duplicate-holding DB investigation)              │
Step 6 (R1: chatbot decimal-separator fix, piggybank-backend)   ─┘

Step 2 (RA/TFSA ledger ListView.builder)         ─┐
                                                    ├─ Step 4 depends on Step 2
Step 4 (Login validation-text fix + 12-file        │  (both touch ra_ledger_screen.dart /
        tooltip pass + trivial profile_api.dart    │  tfsa_ledger_screen.dart — serialize to
        lint fix)                                  ┘  avoid a merge conflict, don't parallelize)

Step 7 (Final regression + consolidation) ── depends on Steps 1-6 all being merged
```

**Recommended execution order:** Steps 1, 2, 3, 5, 6 first (2 before 4, the rest in any order/in
parallel — they touch disjoint files). Step 4 after Step 2 merges. Step 7 last.

---

## Step 1 — Transactions screen: fix FAB overlap (M3) and switch to `ListView.builder` (M2)

**Type:** Flutter UI. **Model:** default. **Independent — no dependency on other steps.**

**Context brief:** Two separate findings on the same screen/file, bundled into one PR since
fixing them independently would mean two agents editing the same file in sequence for no benefit.
M3 is the higher-severity, user-visible bug (a transaction's amount can be fully hidden behind the
floating "Add transaction" button at certain scroll depths); M2 is a lazy-loading correctness/
performance improvement to the same list.

**Task list:**
1. **M3 fix:** In `lib/features/transactions/screens/transactions_screen.dart`, add bottom padding
   to both `ListView`s (the empty-state one at ~line 87 and the main one at ~line 96) sized to
   clear the `FloatingActionButton.extended`'s footprint — a standard `EdgeInsets.only(bottom:
   16 + kFloatingActionButtonMargin + <FAB height, ~56>)` or equivalent, or use
   `MediaQuery.paddingOf(context).bottom` plus a fixed FAB-clearance constant if a similar pattern
   already exists elsewhere in the app (grep for `kFloatingActionButtonMargin` or existing FAB
   overlap handling before inventing a new constant). Alternatively, set
   `floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat` combined with padding,
   or dock the FAB above content via `Scaffold`'s `persistentFooterButtons` if that fits the design
   better — pick whichever keeps the FAB's current visual style (verify against the current
   Stitch mockup if one exists for this screen).
2. **M2 fix:** Convert both `ListView(children: [...])` instances on this screen to
   `ListView.builder`. The main list's structure (date-header + `GroupCard` per group, plus a
   trailing "Load more" button) needs care converting cleanly to a single flat `itemBuilder` —
   either flatten `groups.entries` into a single indexed list (header rows interleaved with
   `GroupCard` rows) before handing it to `.builder`, or use `SliverList`/`CustomScrollView`
   with one sliver per date group if that's a cleaner fit than forcing everything into one flat
   `itemBuilder`. Keep the "Load more" button's position and behavior identical — it must still
   render once, after the last group.
3. Manually re-verify M3's repro from the audit report: scroll to a depth where a row previously
   sat under the FAB, confirm the amount is now fully visible.
4. Add/update a widget test asserting the list uses `ListView.builder` (or asserts the specific
   behavior fixed) if the existing test file for this screen has a natural place for one —
   don't force a new test file into existence if the coverage story doesn't already fit.

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test test/features/transactions/
```
Plus the manual scroll-depth re-check from Task 3 (screenshot before/after, matching the audit
report's repro).

**Exit criteria:** `flutter analyze` clean, `flutter test` green, M3's repro no longer reproduces
at either previously-affected scroll depth, list still renders identically (date grouping,
"Load more" button, empty state) at the demo account's current data volume.

---

## Step 2 — RA/TFSA ledger screens: switch to `ListView.builder` (L1)

**Type:** Flutter UI. **Model:** default. **Independent of Step 1, 3, 5, 6. Step 4 depends on
this step finishing first (same files).**

**Context brief:** Same pattern as Step 1's M2 fix, lower severity (annual contribution caps keep
row counts small), on two files instead of one.

**Task list:**
1. Convert `lib/features/ra/screens/ra_ledger_screen.dart:39`'s `ListView(children:)` to
   `ListView.builder`.
2. Do the same for `lib/features/tfsa/screens/tfsa_ledger_screen.dart:39`.
3. Confirm both screens' existing content (growth-projection table, contribution history) still
   renders identically — these screens were live-verified working in the 2026-08-31 report; don't
   regress them.

**Verification:**
```bash
flutter analyze
flutter test test/features/ra/ test/features/tfsa/
```
Manual: open both ledger screens on the emulator against the demo account (per Piggybank QA
history, unlocking these requires a portfolio of `portfolio_type: "tfsa"`/`"ra"` — the two QA
portfolios created for this purpose in a prior session, `QA TFSA Portfolio` / `QA RA Portfolio`,
should still exist; confirm before assuming you need to create new ones).

**Exit criteria:** Both files converted, tests green, both screens visually unchanged on a live
walkthrough.

---

## Step 3 — `AuthApi`: add request timeouts (M1)

**Type:** Flutter/Dart. **Model:** default. **Independent — no dependency on other steps.**

**Context brief:** Mirror the exact fix already applied to `ApiClient` for H6 (see the grounding
note above) onto this second, deliberately-separate Dio instance used only for
`/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/password-reset/request`. Do **not**
merge `AuthApi` into `ApiClient` or otherwise remove the separation — the existing doc comment
explains it avoids a circular dependency with the refresh interceptor; that reasoning still
holds.

**Task list:**
1. In `lib/core/auth/auth_api.dart:21`, change the default `Dio` construction to set
   `connectTimeout`, `sendTimeout`, and `receiveTimeout` using the same values as
   `lib/core/api/api_client.dart:27-31` (8s connect, 15s send, 15s receive) — these four
   auth endpoints have no legitimate reason to need longer than the app's own general default.
2. Confirm no auth flow (register, login, refresh, password-reset request) has an existing
   integration/widget test that mocks `Dio` in a way this change would break (a test asserting the
   exact `BaseOptions` passed, for instance) — update if so, don't just make the test pass by
   loosening its assertion without understanding why it changed.

**Verification:**
```bash
flutter analyze
flutter test test/core/auth/ test/features/auth/
```

**Exit criteria:** `AuthApi`'s default constructor sets the same three timeouts as `ApiClient`,
all auth-related tests still pass, the class's existing "why a separate client" doc comment is
left intact (update it only if it needs a one-line addition noting the timeout parity, not a
rewrite).

---

## Step 4 — Login validation-text fix (M4) + accessibility tooltips across 12 files (L2) + trivial lint cleanup

**Type:** Flutter UI/accessibility. **Model:** default. **Depends on Step 2** (both touch
`ra_ledger_screen.dart` / `tfsa_ledger_screen.dart` — run this step only after Step 2's branch is
merged, to avoid a same-file merge conflict; rebase onto `master` after Step 2 lands before
starting this step's edits).

**Context brief:** Three unrelated-but-small fixes bundled into one PR because L2 alone already
touches 12 files and two of those files (`ra_ledger_screen.dart`, `tfsa_ledger_screen.dart`)
overlap Step 2's edits — batching keeps the overlap to one clean rebase instead of two separate
PRs racing each other on the same lines. M4 and the lint fix are unrelated but trivial enough not
to warrant their own PR each.

**Task list:**
1. **M4 fix:** In the login screen's password (and any other) field validator/error-display
   logic (`lib/features/auth/screens/login_screen.dart` — locate the `TextFormField`'s
   `validator`/`onChanged` wiring), ensure the error text clears as soon as the field becomes
   valid, not only on next form submission. The field's border/label colour already updates
   correctly on each keystroke (confirmed in the audit) — the fix is almost certainly re-running
   validation (or clearing a manually-tracked error string) in the same `onChanged` callback that
   already updates the valid/invalid styling, rather than only in the `validator` callback that
   `Form.validate()` invokes on submit.
2. **L2 fix:** Add a `tooltip:` to every icon-only `IconButton` currently missing one, across
   these 12 files (grep `IconButton(` vs `tooltip:` per file to confirm you've caught all of
   them — the exact per-file counts from the audit are a starting list, not a ceiling):
   `lib/features/auth/screens/login_screen.dart`, `register_screen.dart`,
   `reset_password_screen.dart`, `lib/features/budgets/screens/budgets_screen.dart`,
   `lib/features/insights/screens/insights_screen.dart`,
   `lib/features/liabilities/screens/liability_detail_screen.dart`,
   `lib/features/portfolios/screens/holding_detail_sheet.dart`, `invest_screen.dart`,
   `portfolio_detail_screen.dart`, `lib/features/ra/screens/ra_ledger_screen.dart`,
   `lib/features/settings/screens/data_export_screen.dart`,
   `lib/features/tfsa/screens/tfsa_ledger_screen.dart`. Each tooltip string should describe the
   action (e.g. "Edit account", "Delete holding"), not just repeat the icon's shape.
3. **Trivial lint fix:** Resolve the 2 `use_null_aware_elements` info-lints in
   `lib/features/settings/data/profile_api.dart:22-23` (noted in the audit as clean-but-trivial,
   not a numbered finding) — apply whatever `dart fix` or manual null-aware-element syntax the
   lint suggests.
4. Re-run the audit's L2 grep methodology (`IconButton(` occurrences vs `tooltip:` occurrences per
   file) across the whole `lib/` tree, not just the 12 listed files, to confirm no file was missed
   by the original audit either.

**Verification:**
```bash
flutter analyze     # should show 0 issues after the lint fix, down from 2
flutter test
```
Manual: tab through the login screen's password field with an invalid-then-corrected value,
confirm the error text disappears as soon as the field turns valid (matching the audit's exact
repro in reverse).

**Exit criteria:** `flutter analyze` fully clean (0 issues, not just 0 warnings), every
`IconButton` in `lib/` has a `tooltip`, login validation text clears live without requiring
submission.

---

## Step 5 — Investigate the GLD duplicate-holding discrepancy (L3)

**Type:** Backend/DB investigation (read-only first). **Model:** default. **Independent — no
dependency on other steps.**

**Context brief:** Two "GLD — SPDR Gold Shares ETF" rows on the demo account's Invest tab show
identical current value but a ~R784k swing in unrealized P&L between them. This could be two
legitimate lots (different portfolios, different cost bases) or a phantom duplicate from an
unguarded reseed — this app's own history (`QA_FINDINGS.md`'s 2026-09-01 update) already
documents exactly this class of bug for transactions (`create_transactions()` re-running without
a duplicate check). Resolve which it is before deciding whether any fix is needed at all.

**Task list:**
1. Run the read-only query, corrected against the actual schema (adversarial review caught the
   audit's own query using the wrong column name — `holdings` has no `symbol` column, it's
   `ticker`, confirmed in `backend/app/models.py`'s `Holding` model): `SELECT id, ticker, quantity,
   cost_basis, portfolio_id FROM holdings WHERE ticker = 'GLD'` against the demo account's data
   (via SSH + `psql` on the Tailscale backend, matching this app's established read-only DB-audit
   pattern from the prior full-suite QA blueprint's Step 3).
2. **Treat same-portfolio duplication as the primary hypothesis, not a fallback** (reordered from
   this plan's first draft after adversarial review): `backend/scripts/seed_test_user.py`'s
   `create_portfolio_and_holdings()` reuses the existing portfolio on a re-run (free-tier limit is
   one portfolio) but then unconditionally re-POSTs every row in its hardcoded `HOLDINGS` list
   (including GLD) with no existing-row check — the exact `create_transactions()` dedup gap
   already found and fixed once for transactions (`QA_FINDINGS.md`'s 2026-09-01 update), never
   fixed for holdings. A second GLD row in the *same* `portfolio_id` from a repeat seed run is the
   likely outcome here, not an edge case. Check this first.
3. Only if both rows genuinely point at *different* `portfolio_id`s (cross-reference against the
   demo account's actual portfolio list — the "3 portfolios" figure in the original audit was
   asserted, not verified against the seed script, so confirm the real count rather than trusting
   it) does the legitimate-two-lot explanation apply — close as a confirmed non-issue in that case.
4. If Task 2 confirms a same-portfolio duplicate, propose the fix (either a one-off `DELETE` of
   the extra row, or an idempotency guard in `seed_test_user.py` mirroring however the
   transactions-dedup gap was eventually addressed) but do **not** apply a destructive `DELETE`
   against demo data without the user's explicit go-ahead (per this app's established practice for
   any demo-data mutation).
5. Write up the finding either way — "confirmed duplicate row, [fixed / fix proposed pending user
   sign-off]" or "confirmed legitimate two-lot holding, no action" — as a closing note.

**Verification:** N/A (investigative) — the deliverable is a clear, evidence-backed conclusion,
not a code diff (unless Task 3 finds a real bug and a trivial fix applies).

**Exit criteria:** L3 is closed with a definitive answer (not "still ambiguous"), backed by the
actual query result and portfolio cross-reference.

---

## Step 6 — Chatbot decimal-separator formatting fix (R1)

**Type:** Backend (`piggybank-backend`). **Model:** default. **Independent — no dependency on
other steps, different repo from Steps 1-4.**

**Context brief:** The fix-it blueprint's H2/M6 close-out already fixed the chatbot's currency
*symbol* (was `$`, now correctly `R`) and pre-formats money values with space-thousands
separators before they reach the LLM (per `QA_FINDINGS.md`'s 2026-09-01 update). This step closes
the remaining gap: the model still emits a **period** decimal separator (e.g. "R 5 286 030.50")
instead of the app's SA convention (comma decimal, "R 5 286 030,50") used everywhere else
(Dashboard, Accounts, Budgets, Goals).

**Task list:**
1. Fix the pre-formatting function itself: `backend/app/chatbot/service.py`'s `_zar()` (confirmed
   at line ~22-31) currently does `f"{value or Decimal('0'):,.2f}".replace(",", " ")` — this only
   replaces the thousands comma with a space, leaving Python's default **period** decimal
   separator untouched. Change it to also swap the decimal point for a comma (order matters: swap
   the thousands separator to a placeholder, then the decimal point to a comma, then the
   placeholder to a space — a naive two-step `.replace(",", " ").replace(".", ",")` is safe here
   only because there's no other period in the formatted string, but write it defensively anyway).
2. **Also fix the two guardrail prompts' own literal examples — adversarial review caught this;
   fixing only `_zar()` would leave the bug half-fixed.** Both `backend/app/chatbot/service.py`
   (~line 477-479, the "Copy each number exactly as given ... e.g. 'R 1 808 030.50'" instruction)
   and `backend/app/services/ai_context.py` (~line 269, "the context value 12345.67 is shown as
   R 12 345.67") tell the model to copy a *period*-decimal example verbatim — even after `_zar()`
   emits comma-decimal values, these stale literal examples could bias the model back toward a
   period. Update both examples to the corrected comma-decimal format.
3. Extend the fix consistently — both surfaces (chatbot `service.py` and the separate `ai_context.py`
   insights/`ask` guardrail) format money independently; confirm neither has a second, undiscovered
   formatting helper doing the same job differently.
4. Live-verify: ask the chatbot the same question from the audit's repro ("Show my net worth
   trend") **and** the Insights `ask` surface (the `ai_context.py` guardrail's own surface, not
   previously tested for this) and confirm both now read with a comma decimal separator, matching
   the Dashboard's rendering of the same figure at the same moment.

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\piggybank-backend"
docker compose --profile test run --rm backend-test
```
(Note: `docker-compose.yml` lives at the repo root, not under `backend/` — the first draft of
this plan had the wrong working directory here.) Plus the live re-tests in Task 4 — this is the
actual acceptance criterion, since the bug is only observable in the model's live text output.

**Exit criteria:** A live chatbot query *and* a live Insights `ask` query reporting a monetary
figure both use a comma decimal separator, matching every other screen in the app. **Deploy story
corrected after adversarial review:** confirm whether the push to `main` actually triggered
`.github/workflows/deploy.yml`'s automated `deploy` job (check the Actions run) — if it ran and
succeeded, the change is live; if it didn't fire or failed, deploy manually via `docs/runbook.md`'s
`git pull` steps on the server (the *current* authoritative manual path, not tar+scp, which is
only the fallback for when the server's GitHub access itself is broken). Either way, live-verify
against the actual production Tailscale backend before closing this step, not just the local
test suite.

---

## Step 7 — Final regression + consolidation

**Type:** Documentation/verification. **Model:** default. **Depends on Steps 1-6 all being
merged (and Step 6 deployed).**

**Context brief:** Close the loop the same way the prior fix-it blueprint did — one final
regression pass, then update the findings index so the next session doesn't have to re-derive
what's closed.

**Task list:**
1. Full regression: `flutter analyze` (expect 0 issues), `flutter test` (expect 427/427 or higher
   if Steps 1/2 added tests), backend `pytest` (expect the same pass count as the audit's
   baseline plus no new failures).
2. Live re-verify each fixed finding once more, back-to-back, on the emulator: M3 (scroll depth
   check), M2/L1 (visually unchanged, still renders correctly — lazy-loading isn't visually
   observable but a crash/blank-list regression would be), M1 (can't be directly observed live
   without simulating a timeout, so rely on the automated test from Step 3), M4 (validation text
   clears live), L2 (spot-check 2-3 of the 12 files' tooltips render on long-press), R1 (chatbot
   decimal separator), L3 (whatever Step 5 concluded).
3. **Do not add a second same-date section** — `QA_FINDINGS.md` already has a **2026-09-11**
   "Update" section (written by the audit itself before this plan existed, per the Pre-flight note
   above) describing these 7 findings as open. Either (a) edit that existing section in place to
   mark each finding as closed/confirmed-non-issue with a one-line pointer to this plan, or (b) add
   a new section dated the day this step actually runs (if that's a later calendar date) titled
   "closes the 2026-09-11 production audit" — pick whichever this workspace's existing convention
   favours (check how the 2026-09-01 "later same day" section handled the same situation for the
   prior audit, and match it) rather than inventing a third pattern.
4. Commit everything: `Piggybank` — push each remaining unmerged branch, confirm all PRs merged
   to `master`. `piggybank-backend` — confirm Step 6's commit is on `main` **and** actually
   deployed: check whether `.github/workflows/deploy.yml`'s `deploy` job ran and succeeded on that
   push (GitHub Actions run log), and if it didn't fire or failed, complete the manual `git pull`
   deploy steps from `docs/runbook.md` — don't assume tar+scp is needed unless that doc's fallback
   condition (server's GitHub access broken) actually applies.

**Verification:** The exact pass/fail/skip counts from Task 1, captured verbatim (not
paraphrased), matching this plan's own convention (see the QA v2 blueprint's Step 1 for the exact
bar: literal counts, not "tests passed").

**Exit criteria:** All 7 findings + 1 regression + 2 trivial lints from
`QA_PRODUCTION_AUDIT_2026-09-11.md` are either fixed-and-verified or explicitly confirmed as
non-issues (L3's possible outcome), `QA_FINDINGS.md` reflects the closure, and the automated
regression suite is green.

---

## Notes for whoever executes this plan

- **Respect Step 4's dependency on Step 2** — both touch `ra_ledger_screen.dart` and
  `tfsa_ledger_screen.dart`; running them out of order or in parallel will produce a merge
  conflict or a silently-overwritten fix.
- **Don't skip Step 5's investigation-before-fix discipline** — per this app's own established
  practice (see `piggybank-full-suite-qa-v2.md` Step 3/4), don't mutate demo data (especially a
  `DELETE`) without the user's explicit go-ahead, even if a duplicate looks obvious.
- **Step 6 is the only step in a different repo, with a deploy story that needs active
  confirmation, not an assumption.** Don't assume a `git push` to `main` either does or doesn't
  ship the change automatically — `.github/workflows/deploy.yml` has an automated deploy job
  gated on that push, but `docs/runbook.md` (as of its 2026-09-06 update) describes that automated
  path as not currently in use, favouring a manual `git pull` on the server instead. Check the
  actual GitHub Actions run for that push before declaring R1 deployed.
- **This plan was adversarially reviewed before finalizing** (2026-09-11) — the review caught and
  this revision fixed: a stale/inverted deploy-mode description, an incorrect claim that
  `piggybank-backend` has no PR-based CI, a wrong DB column name in Step 5's query (`ticker` not
  `symbol`), Step 5's investigation order (same-portfolio duplication should be checked first, not
  treated as a fallback — the seed script's own re-run behavior makes it the likely explanation),
  a missed second fix location in Step 6 (the guardrail prompts' own literal decimal-formatted
  examples, not just `_zar()`), a wrong working directory in Step 6's test command, and a
  same-date duplicate-section risk in Step 7 (fixed via the Pre-flight note and Step 7 Task 3's
  revision above).
- This plan does not re-open or duplicate anything from `plans/piggybank-fix-it.md` (already
  closed) — it only addresses findings unique to the 2026-09-11 audit.
