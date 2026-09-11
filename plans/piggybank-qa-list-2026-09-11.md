# Piggybank — Close Out the 2026-09-11 QA List

**Objective:** Resolve every still-open item from today's two QA passes (the production-audit
fix-it blueprint's carried-forward finding, and the new `QA_VISUAL_UIUX_AUDIT_2026-09-11.md`),
and land the uncommitted doc work sitting in the working tree.

**Mode:** Git + no `gh` CLI on this machine. PRs are opened directly via the GitHub REST API using
the token from `git credential fill` (established pattern from PRs #5–#7 in the Flutter repo).
Doc-only commits go straight to `master`/`main` (matches this repo's own convention — see
commit `0ea9947`, a docs-only commit made directly to master, vs. every code fix going through a
`fix/*` branch + PR).

**Repos involved:**
- `C:\Fynbos Creative Master\02_Clients\Piggybank` — Flutter app, remote `origin` →
  `Tiaanbossies/piggybank`, default branch `master`.
- `C:\Fynbos Creative Master\02_Clients\piggybank-backend\backend` — FastAPI backend, remote
  `origin` → `Tiaanbossies/piggybank-backend`, default branch `main`.
- Production VPS: `ssh mcp@100.121.165.7`, deploy = `cd ~/piggybank-backend && git pull &&
  docker compose --env-file .env.docker up -d --build`.

**Key research finding (read this before executing Step 2 — supersedes the plan's original Step 2,
which was wrong):** the "unlogged" money-formatting bug is actually **two independent code paths**,
only one of which commit `15e9179` (pushed to `origin/main`) fixed:
- `POST /api/insights/generate` (`insights/router.py`'s `generate_legacy` → `ask_insight` →
  `services/ai_context.build_prompt`) — **fixed** by `15e9179`.
- `POST /api/ai/insights` (`app/ai/routes.py`, a separate router → `app/ai/prompts.py`'s
  `build_user_prompt`) — a third, distinct prompt path `15e9179` never touched. No ZAR-formatting
  guardrail exists here at all (raw, unformatted decimal strings JSON-dumped straight into the
  prompt). **Still broken.** `piggybank-backend/CLAUDE.md` warns explicitly about this: "one more
  `/ai`-prefixed router bypasses the flag entirely... don't assume every `/ai`-prefixed route
  respects the flag."
Separately, `QA_FINDINGS.md`'s claim that `15e9179` was "deployed via manual `git pull` + `docker
compose up`" conflicts with `piggybank-backend/CLAUDE.md`, which says the production `mcp` user
has no GitHub credentials and the real deploy path is `git ls-files | tar czf ... | scp`. Confirm
which actually happened before trusting "already live."

---

## Step 1 — Land pending doc corrections (Flutter repo, direct to master)

**Depends on:** nothing. **Parallel-safe with:** Steps 2, 3, 5.

**Context:** `QA_FINDINGS.md` already has an uncommitted 33-line close-out addition (`git diff
--stat` confirms it), and `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md` exists on disk but is
untracked. Both are finished content from the prior session, just never committed.

**Tasks:**
1. `git add QA_FINDINGS.md docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`
2. In `QA_FINDINGS.md`, append a short correction note under the existing "out-of-scope finding"
   paragraph (the one mentioning `/api/insights/generate` and `/api/ai/insights`): state that this
   was fixed same-day in `piggybank-backend` commit `15e9179` (pushed to `origin/main`), and that
   production-deploy confirmation is tracked as Step 2 of
   `plans/piggybank-qa-list-2026-09-11.md`.
3. Commit both files together, message describing the close-out + audit doc landing.
4. `git push origin master`.

**Verification:** `git log -1 --stat` shows both files; `git status --short` is clean for these
two paths; `git log origin/master -1` matches local after push.

**Exit criteria:** doc work committed and pushed, no untracked/modified QA files remain.

---

## Step 2 — Fix `/api/ai/insights`, then verify+deploy both fixes (backend repo)

**Depends on:** nothing. **Parallel-safe with:** Steps 1, 3, 5.

**⚠️ Flag for the user:** a prior action in this session attempting a read-only `ssh` command to
the production host (`100.121.165.7`) was denied by the harness's auto-mode classifier with reason
"Production Reads." The verify/deploy sub-steps below may require the user to either grant that
permission or run those commands themselves. Do not attempt to route around the denial with
another tool.

**Context:** `POST /api/insights/generate` is already fixed by commit `15e9179` (delegates to the
patched `services/ai_context.build_prompt`) — no code change needed there. `POST /api/ai/insights`
(`app/ai/routes.py` → `app/ai/prompts.py`'s `build_user_prompt`) is a separate, still-broken code
path `15e9179` never touched — it has no ZAR-formatting guardrail at all.

**Tasks:**
1. In `app/ai/prompts.py`, add the same kind of guardrail `15e9179` added to
   `services/ai_context.py`'s `build_prompt` and `chatbot/service.py`'s `_zar()`: either
   pre-format amounts in `context_builder.build_finance_context`'s `_s()` helper to South African
   convention (space-thousands, comma-decimal) before they're JSON-dumped, or add an explicit
   instruction + example to `SYSTEM_PROMPT` telling the model the convention (mirroring the
   guardrail text already used in `chatbot/service.py`/`services/ai_context.py`). Prefer
   pre-formatting — the `_zar()` docstring's own reasoning (small local models drop digits when
   re-grouping raw numbers themselves) applies here too.
2. Add/update unit tests covering the new formatting (mirror `test_zar_formats_with_space_
   thousands_and_comma_decimal` from `15e9179`'s test additions).
3. Branch `fix/ai-insights-money-formatting` off `main`, commit, push, open a PR via the GitHub
   REST API + credential-helper token (same method used for the Flutter repo's PRs).
4. Once merged (or if the user wants it deployed immediately after review): check what commit is
   currently deployed (`ssh mcp@100.121.165.7 "cd ~/piggybank-backend && git log -1 --oneline"` —
   requires the flagged permission), and deploy via this repo's actual documented path
   (`git ls-files | tar czf ... | scp` into `~/piggybank-backend`, per `piggybank-backend/
   docs/runbook.md` — confirm the exact command there rather than assuming `git pull` works, since
   the `mcp` user has no GitHub credentials).
5. Confirm live: hit `/api/ai/insights` (and, for good measure, `/api/insights/generate`) via the
   app or a direct authenticated request, and confirm ZAR amounts render comma-decimal
   (`R 1 808 030,50`), not period-decimal or thousands-comma.

**Exit criteria:** `app/ai/prompts.py` has the same ZAR guardrail as the other two AI code paths;
PR opened/merged; production confirmed running a commit that includes it; a live response from
both `/api/ai/insights` and `/api/insights/generate` shows comma-decimal ZAR formatting.

---

## Step 3 — M1 fix: Budgets empty state (Flutter repo, branch + PR)

**Depends on:** nothing. **Parallel-safe with:** Steps 1, 2, 5.

**Context:** `lib/features/budgets/screens/budgets_screen.dart:66-68` renders a bare
`Text('No budgets for this month.')` for the empty state — no icon, no pointer to the Add Budget
FAB already floating in the corner. Every other zero-content screen in the app (Goals, Invest) has
a clearer path forward. This is flagged Medium in `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`
("M1").

**Tasks:**
1. Branch `fix/budgets-empty-state` off `master`.
2. Before writing the fix, read one other screen's empty/zero state (check `goals_screen.dart` and
   `invest`'s empty state, or `category_icons.dart` for the icon family already in use) so the new
   empty state matches the app's existing visual language rather than inventing a new pattern.
3. Replace the `Text`-only empty state with: an icon from the same family used elsewhere (e.g. a
   light pie-chart or wallet outline glyph, not a new icon style), plus one line of copy that
   references the Add Budget action (mirroring how other screens narrate their primary action).
4. `test/features/budgets/screens/budgets_screen_test.dart` already exists — update its empty-state
   assertion(s) to match the new content, and add one asserting the new icon/CTA copy renders.
5. `flutter analyze` → must stay 0 issues. `flutter test` → must stay green.
6. Push branch, open PR via GitHub REST API using the credential-helper token (same method as PRs
   #6/#7: `git credential fill <<< $'protocol=https\nhost=github.com\n'`, then `curl -X POST
   .../repos/Tiaanbossies/piggybank/pulls`). Never echo the token.
7. Ask the user to merge (or merge directly via the API's merge endpoint if the user has
   pre-authorized that in this session).

**Exit criteria:** PR opened (and, once the user confirms, merged) with the new empty state;
`flutter analyze` 0 issues; `flutter test` green.

---

## Step 4 — L1 fix: Notifications screen dead space (Flutter repo, branch + PR)

**Depends on:** none strictly, but run after Step 3 lands to avoid two branches touching the app
shell at once if they turn out to overlap. **Not parallel with Step 3** (same repo, sequence
after it).

**Context:** `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`'s L1 flags four screens with large blank
areas below short content (Accounts, Notifications, Subscription, Loan Calculators), calling
Notifications "especially sparse" with just 2 toggle rows. The audit itself calls this "not a
defect... a layout opportunity," not a bug — so this step deliberately narrows scope to the single
highest-confidence case rather than guessing layout changes across four screens that weren't all
inspected in equal depth.

**Tasks:**
1. Branch `fix/notifications-dead-space` off `master` (or off `fix/budgets-empty-state` if that
   hasn't merged yet — rebase onto `master` before opening the PR either way).
2. Edit `lib/features/settings/screens/notifications_screen.dart`. Change its short toggle-row
   list from top-anchored to vertically centered in the available space (e.g. wrap in `Center` or
   use `mainAxisAlignment: MainAxisAlignment.center` on the containing `Column`), matching the
   audit's suggested fix.
3. Leave Accounts, Subscription, and Loan Calculators **untouched** — log them in this plan's
   close-out (Step 7) as still-open polish items, since narrowing scope beats guessing at three
   screens' full layouts from a written description alone.
4. `flutter analyze` 0 issues; `flutter test` green.
5. Push branch, open PR via the same REST API method as Step 3.

**Exit criteria:** Notifications screen no longer looks sparse in a manual re-screenshot (deferred
to Step 6 if the emulator is available then); Accounts/Subscription/Calculators explicitly logged
as not-yet-attempted, not silently dropped.

---

## Step 5 — L2 & L3: record design decisions, no code change (Flutter repo, direct to master)

**Depends on:** nothing. **Parallel-safe with:** Steps 1, 2, 3, 4.

**Context:** L2 (filled-vs-outline avatar icon) and L3 (green's dual semantic duty) are both
judgment calls, not defects — the audit itself says L3 is "a deliberate one-accent-color design
trade-off... not an oversight." Making a blind code change here without a design decision would be
guessing; the audit's own recommendation is to make the call deliberate rather than incidental.

**Tasks:**
1. Record the decision: keep the filled avatar icon as-is. Rationale: a visually distinct
   "profile entry point" affordance is a common, intentional pattern (distinguishing "opens your
   account" from every other in-content icon) — treat the one filled/outline mix as intentional,
   not inconsistent. If the user disagrees and wants the outline style instead, that's a one-line
   icon-family swap that can be added to Step 3 or Step 4's PR as a follow-up, not a reason to
   block this step.
2. Record L3 as closed with no action: the single-accent-color trade-off is already documented in
   `app_theme.dart`'s own comment, red is reserved exclusively for negative amounts (polarity
   signal survives), and no code change is proposed.
3. Edit `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`'s L2 and L3 sections to append a "**Decision
   (2026-09-11):**" line under each, recording the above.
4. Commit directly to `master`, doc-only.

**Exit criteria:** both L2 and L3 marked as decided (not merely "flagged") in the audit doc;
commit pushed.

---

## Step 6 — L4: live dark-mode verification pass (Flutter repo, emulator — conditional)

**Depends on:** Steps 3 and 4 merged (so the screenshots reflect the final, fixed UI, not a
pre-fix state). **Blocked precondition:** sufficient free memory — this machine OOM-killed both a
debug and a release emulator build earlier today.

**Tasks:**
1. **Gate first, every time:** run `Get-CimInstance Win32_OperatingSystem | Select
   FreePhysicalMemory` and `Get-Process | Sort-Object WorkingSet -Descending | Select -First 15`.
   Kill any orphaned `dart`/`dartaotruntime`/`qemu-system-x86_64` processes from prior failed
   attempts. Do not attempt the emulator unless free memory is comfortably above what two prior
   OOM kills required (aim for several GB more headroom than the ~3-4GB baseline that failed
   twice today).
2. If memory is still insufficient: **stop here**, do not force a third attempt (per this
   session's own prior decision to pivot away from forcing OOM-prone builds), and leave L4 flagged
   open in the close-out (Step 7).
3. If memory allows: `flutter emulators --launch piggybank`, then `flutter run --release` (prefer
   release since that's the build type that matches production behavior), navigate to Settings →
   Appearance → Dark, and screenshot Dashboard, Transactions, Login, and Budgets (to also visually
   confirm Step 3's M1 fix and Step 4's L1 fix landed correctly).
4. Save screenshots under `qa_screens/dark/`, commit them.
5. Update `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`'s L4 section: mark verified, with a note on
   what was confirmed and links to the new screenshot files.

**Exit criteria:** either L4 is visually verified with committed dark-mode screenshots, or it is
explicitly still blocked with the exact memory numbers logged (not silently skipped).

---

## Step 7 — Final close-out (Flutter repo, direct to master)

**Depends on:** Steps 1–6 (or their explicit blocked/deferred state).

**Tasks:**
1. Add a final "2026-09-11 QA list close-out" section to `QA_FINDINGS.md` summarizing:
   - Step 1: doc corrections landed.
   - Step 2: money-formatting fix confirmed live in production (or still pending user action, if
     the SSH permission denial wasn't resolved).
   - Step 3: M1 fixed, PR number, merged or pending merge.
   - Step 4: L1 fixed for Notifications only; Accounts/Subscription/Calculators explicitly still
     open.
   - Step 5: L2 and L3 closed by decision, no code change.
   - Step 6: L4 verified with screenshots, or still blocked (with the reason).
2. Commit and push.

**Exit criteria:** one document trail exists showing every item from today's QA list is either
done, decided, or explicitly still open with a named reason — nothing left as an orally-carried
TODO.

---

## Anti-patterns to avoid

- Do not re-fix the money-formatting bug in code — it's already fixed; Step 2 is verify/deploy
  only.
- Do not guess layout changes for Accounts/Subscription/Calculators in Step 4 without inspecting
  each screen's actual widget tree first — if time allows, expand scope deliberately rather than
  silently.
- Do not force a third emulator attempt in Step 6 without confirming free memory first — two OOM
  kills already happened today.
- Do not skip opening PRs for Steps 3 and 4 just because `gh` isn't installed — use the REST API +
  credential-helper token method that already worked for PRs #6 and #7.
