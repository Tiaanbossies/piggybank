# Blueprint: Navigation/UX polish, Stitch UI pass, and in-app OTA update notification

**Objective:** Three sequential improvements to the Piggybank Flutter app: (1) fine-tune
screen navigation/transition polish, (2) a targeted Stitch MCP UI pass to close the
remaining visual-audit gaps and design the one genuinely unbuilt screen (a real
analytics/trends "Insights" surface), and (3) an in-app update-check notification so
users on a sideloaded APK learn a new build exists, served over the existing Tailscale
infrastructure. The app should read as production-grade throughout — no regressions to
the already-passing visual QA audit, no half-finished screens.

**User's own framing (verbatim intent):** "I want to further fine tune the page/screen
navigation of the piggybank app to improve UX and flow between screens. I then want to
use Stitch MCP, to further improve the UI and screens for the app. The app should be
production level, highly professional, clean, can compete with paid finance tracking
apps, whilst still in production. I also want to use an API using the tailscale domain
to download updates to the app in the future." Refined via a prior prompt-optimizer pass
and three confirmed decisions: update UX is **notify + manual download only** (no
in-app APK download, no `REQUEST_INSTALL_PACKAGES`, no auto-install); the API base
switches to the **Tailscale MagicDNS domain for all traffic**, not just the update
check; and the Stitch pass is **targeted** (close audit findings + build the one
net-new screen), not a full redesign.

**Mode:** Git branches + manual PR (no `gh` CLI on this machine — confirmed `gh: command
not found`). `Piggybank` has a real `origin` remote
(`https://github.com/Tiaanbossies/piggybank.git`, default branch `master`) — push each
branch and open the PR manually via the browser link Git prints after `git push`,
matching how the most recent prior branch (`penny-onboarding-tour`, PR #10) was merged.
`git status --short --branch` currently shows `master` in sync with `origin/master`,
working tree clean.

---

## Grounded against the live files before drafting (2026-09-13)

**Navigation (`lib/core/router/`):**
- `app_router.dart` — single `GoRouter`, `initialLocation: '/login'`. Top-level routes:
  `/login`, `/register`, `/forgot-password`, `/reset-password`, `/lock`, `/consent`,
  `/onboarding`, `/settings/data-export`. A `StatefulShellRoute.indexedStack` with 5
  branches: `/` (Dashboard), `/invest` (Invest), `/budgets` (BudgetsHomeScreen),
  `/assistant` (Chatbot), `/settings` (SettingsScreen). `computeRedirect(AuthState,
  String)` (lines 77-92) is pure and unit-tested, precedence `locked >
  consentsRequired > onboardingRequired > shell`.
- `app_shell.dart` — `AppShell` wraps `navigationShell` in a `Scaffold` with a Material 3
  `NavigationBar`, 5 destinations. Tab switches call `navigationShell.goBranch(...)`.
  **No page-transition customization exists anywhere** — confirmed via grep, no
  `PageTransitionsTheme`, no `CustomTransitionPage`. `pubspec.yaml` has no
  `animations`/`page_transition` package dependency.
- **Important mechanism distinction the execution steps must respect**: a
  `ThemeData.pageTransitionsTheme` override affects **push/pop route navigation only**
  (both go_router's default page wrapper and the plain `Navigator.push(MaterialPageRoute
  (...))` calls used throughout `placeholder_screens.dart`'s `SettingsScreen` for
  Subscription/Notifications/About/etc.) — one theme-level change covers both call
  styles with no per-route edits. It does **not** affect tab switches inside
  `StatefulShellRoute.indexedStack`, because `IndexedStack` swaps its visible child by
  index with no transition mechanism at all; animating *that* requires a bespoke wrapper
  around `navigationShell` in `app_shell.dart` (e.g. an opacity cross-fade keyed to
  `navigationShell.currentIndex`) and is a separate, smaller piece of work. Do not
  conflate the two or assume one fix covers both.
- **Insights naming collision — resolve before Phase 2, not during it.** Two unrelated
  things are both called "Insights" in this codebase:
  1. `lib/features/insights/` (4 files, 346 lines, real working code) — an **AI Q&A
     history** screen (`InsightsScreen`, ask-a-question + history list backed by
     `insights_router`'s `/insights/ask` etc., gated behind `require_pro_tier`). It was
     the 4th bottom-nav tab until `.claude/PRPs/plans/completed/replace-insights-tab-
     with-ai-assistant.plan.md` replaced that slot with the Chatbot/Assistant tab
     specifically **because the two features overlapped** ("ask about your finances" in
     two places). It is unrouted today but left in place, doc comment included
     (`insights_screen.dart:14-19`), "in case the product decides to bring a distinct
     Q&A-history surface back later." Confirmed via grep: **nothing outside
     `lib/features/insights/` imports it** except a one-line doc-comment mention in
     `chatbot_screen.dart:27` (no code dependency).
  2. `docs/stitch-design-brief.md`'s proposed **"Insights tab"** (§8, lines 273-279) is a
     completely different concept: a **trends/analytics dashboard** (net-worth-over-
     time, spending-pattern callouts, budget-adherence trends), explicitly marked "new —
     currently a bare placeholder, no precedent at all" and called "the highest-value
     new-design target in the whole brief."
  Re-routing the *existing* Q&A `InsightsScreen` back into the nav would recreate the
  exact duplication the Assistant-tab change was made to fix. The right move — and what
  the steps below do — is: **delete** the dead Q&A insights code (Step 2), and **build a
  new, differently-purposed** analytics screen for the brief's actual proposal
  (Step 6) under a **different name — `lib/features/trends/`, not `lib/features/insights/`**.
  Reusing "insights" for the new feature would recreate the same naming trap one level
  down: the backend still has a **live** `/insights` Q&A router (`insights_router`,
  mounted in `piggybank-backend/backend/app/api/router.py`), untouched by Step 2 (which
  is Flutter-only). A Flutter feature named `insights/` calling `/summaries/*` while a
  backend route named `/insights` answers different questions is exactly the kind of
  confusion this plan exists to remove, not reintroduce. (Doc-comment references to the
  old screen, corrected: `lib/features/chatbot/screens/chatbot_screen.dart:15,25-27`
  and `lib/core/router/placeholder_screens.dart:15` — not a single line at `:27`.)
- **No 6th nav tab.** Material 3 `NavigationBar` guidance and this app's own precedent
  (exactly 5, unchanged since launch, `DESIGN.md` § Navigation) argue against a 6th
  bottom-nav destination. The new analytics screen (Step 6) is reached via an entry
  point on the Dashboard tab instead (e.g. a tappable summary card/tile, mirroring how
  `account_detail_screen.dart` is already reached by tapping a row on Accounts) — not a
  new `StatefulShellBranch`.

**Design system / Stitch (root + `lib/`):**
- `DESIGN.md` (canonical, shipped) and `docs/stitch-design-brief.md` (a second, more
  opinionated Stitch input brief) both exist; prior Stitch batches already ran
  (`plans/stitch-batch4-leftover-prompts.md`, `stitch-batch5-prompts.md`,
  `stitch-live-verification.md`). `lib/core/theme/app_theme.dart` implements `AppColors`
  (separate light/dark hex constants) and `AppSemanticColors` (a `ThemeExtension`).
  `lib/shared/widgets/` holds the reusable component library (`hero_metric_card.dart`,
  `progress_card.dart`, `group_card.dart`, `icon_chip.dart`, `state_views.dart`'s
  `EmptyState`, etc.) — any new screen must compose from these, not invent new ones,
  per the brief's own §9 instruction to keep the app reading as one coherent system.
- **`docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`'s M1 finding is ALREADY FIXED — do not
  re-do it.** The doc's own "Decision (2026-09-11)" section confirms the empty-state fix
  was verified in both light and dark mode. Live-checked against
  `lib/features/budgets/screens/budgets_screen.dart` directly (2026-09-13): the
  `BudgetsBody` widget's empty-data branch already renders
  `EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No budgets for this
  month.', hint: 'Tap "Add budget" below to set one up.')` — icon, title, and a hint
  pointing at the FAB are all present. **The prior prompt-optimizer draft of this plan
  incorrectly listed M1 as open work; it is not. Skip it.**
- **L1 (dead space on Accounts/Notifications/Subscription/Loan Calculator) has a
  self-contradiction in the audit doc itself** — line 118 says a dark-mode QA pass
  "confirms the L1 fix reads correctly in dark mode too" for Notifications, but line 129
  still lists L1 as unresolved ("L1-L3 are polish-tier and can wait for a dedicated
  design pass"). **Step 4 below exists specifically to resolve this ambiguity by
  screenshotting the current state of all four screens live before generating anything**
  — don't trust the audit doc's text at face value for this one item.
- Screen files for L1: `lib/features/accounts/screens/accounts_screen.dart`,
  `lib/features/settings/screens/notifications_screen.dart`,
  `lib/features/settings/screens/subscription_screen.dart`,
  `lib/features/calculators/screens/calculators_screen.dart` (the Loan Calculator lives
  here, not a separate file).
- **Backend trend data already exists — Step 6 needs no new backend endpoint.**
  `piggybank-backend/backend/app/summaries/router.py` already has
  `get_net_worth_history` (`GET /summaries/net-worth-history`), `get_budget_usage`
  (`GET /summaries/budget-usage`), `get_cashflow`, `get_recurring_expenses`, and
  `get_high_cost_expenses`. Client-side, `lib/features/summaries/data/summaries_api.dart`
  already wraps `netWorth()`, `cashflow()`, and `netWorthHistory()` — but **not**
  `budgetUsage()`, `recurringExpenses()`, or `highCostExpenses()` yet. Step 6 extends
  this existing `SummariesApi` class rather than creating a new API client or a new
  backend module.

**Update delivery / Tailscale (`piggybank-backend`, `Piggybank/scripts/`, `Piggybank/lib/core/api/`):**
- `scripts/publish_release.sh` already SCPs the signed APK to
  `mcp@100.121.165.7:~/piggybank-backend/downloads/` and writes `latest.json`
  (`version`, `buildNumber`, `filename`, `publishedAt`) alongside it — its own comment
  says this is "for a future in-app 'update available' check — not consumed by anything
  yet." `downloads/` is served by Caddy's `handle_path /downloads/*` block, reachable at
  `http://100.121.165.7/downloads/...` and
  `http://tiaanbossies-h81m-ds2.tail886b94.ts.net/downloads/...` (plain HTTP, by design
  — see the Caddyfile's own comment: the public `{$DOMAIN}` can never get a cert here,
  so both addresses stay Tailscale-only intentionally).
- `lib/core/api/api_config.dart` currently hardcodes `http://100.121.165.7:8000/api` as
  `ApiConfig.baseUrl`'s default (overridable via `--dart-define=API_BASE_URL=...`, used
  today to point at a local Docker Desktop backend from the Android emulator). This is
  the **one file** that changes for the "domain everywhere" decision — swap the literal
  IP for `tiaanbossies-h81m-ds2.tail886b94.ts.net`, keep the `--dart-define` override
  mechanism as-is.
- Backend structure: `piggybank-backend/backend/app/main.py` is the FastAPI app factory;
  every feature mounts through `app/api/router.py`'s single `api_router` (one line per
  module, e.g. `api_router.include_router(budgets_router, prefix="/budgets", ...)`). A
  new `updates` module follows this exact pattern for the router itself — **but two
  other files also need touching, confirmed via adversarial review**:
  `docker-compose.yml` (the `backend` service has no bind mount for `downloads/` today
  — only `caddy` does) and `backend/app/config.py` (no `downloads`-path setting exists
  yet). See Step 7 for the exact changes; an earlier draft of this section incorrectly
  claimed no other file needed touching. Per `piggybank-backend/CLAUDE.md`: deploy is
  `ssh mcp@100.121.165.7`, then
  `cd ~/piggybank-backend && git pull && docker compose --env-file .env.docker up -d
  --build` — this plan does not perform that deploy itself (out of scope; a human runs
  it after the PR merges, per this repo's existing convention).
- `lib/features/settings/screens/about_screen.dart` already uses
  `PackageInfo.fromPlatform()` to show `info.version`/`info.buildNumber` — the exact
  pattern Step 8's update-check comparison reuses (no new package needed;
  `package_info_plus: ^8.1.2` is already a dependency).

---

## Explicitly out of scope (this plan)

- **In-app APK download, `REQUEST_INSTALL_PACKAGES`, or any auto-install flow** —
  confirmed decision: notify + link to manual download only.
- **Re-doing M1** (Budgets empty state) — already fixed and verified; touching it again
  risks an unnecessary regression to a screen that already passes QA.
- **A full Stitch redesign** of screens the 2026-09-11 audit already passed (0
  Critical, 0 High) — only the confirmed-open L1 items plus the new Insights screen are
  in scope for Phase 2.
- **Re-routing the old Q&A `InsightsScreen` back into the bottom nav** — superseded by
  the Assistant tab for exactly this reason; it is deleted, not reused, in Step 2.
- **A new backend endpoint for trend/analytics data** — `summaries_router` already
  covers the underlying data (net worth, cashflow, per-month budget usage); Step 6 is a
  client-only build that composes existing endpoints (including calling the existing
  single-month `budgetUsage` endpoint multiple times to build a trend), not a new
  backend route.
- **Running `publish_release.sh` against production, or deploying the backend** — this
  plan builds and verifies the feature; an actual production release/deploy is a
  separate, human-run step after the PRs merge, per this repo's existing convention.
- **CI/CD automation for building/publishing APKs** — out of scope; today's manual
  two-script process continues unchanged.

---

## Dependency graph

```
Step 1 (global PageTransitionsTheme + tab-switch fade wrapper)   ─┐
                                                                    ├─ independent, parallel
Step 2 (delete dead Q&A Insights feature + tests)                 ─┘

Step 3 (live visual QA: transitions + redirect-precedence regression) ── depends on Step 1

Step 4 (live-verify current L1 dead-space state on 4 screens)     ── independent, can run
                                                                       anytime after Step 3
                                                                       (keeps Phase 1/2 boundary
                                                                       clean, not a hard dep)
Step 5 (Stitch: fix confirmed-open L1 screens)                    ── depends on Step 4
Step 6 (Stitch: new Trends analytics screen, lib/features/trends/) ── depends on Step 4
                                                                       only (shared
                                                                       vocabulary confirmed
                                                                       live) — no longer
                                                                       depends on Step 2,
                                                                       since it doesn't
                                                                       reuse the "insights"
                                                                       name

Step 7 (backend: GET /api/updates/latest)                         ── independent
Step 8 (Flutter: Tailscale domain switch + update-check banner)   ── depends on Step 7
Step 9 (end-to-end update-flow verification)                      ── depends on Step 7, 8
```

**Recommended execution order:** Steps 1 and 2 in parallel (disjoint files: Step 1 touches
`lib/core/theme/app_theme.dart` and `lib/core/router/app_shell.dart`; Step 2 touches only
`lib/features/insights/` and its three test files, plus one doc-comment line in
`chatbot_screen.dart`). Step 3 after Step 1 merges. Step 4 can start anytime (independent
research/verification, no code changes) — run it alongside Steps 1-3 to save time. Steps
5 and 6 both after Step 4 merges, and can run in parallel with each other (Step 5 touches
`accounts_screen.dart`/`notifications_screen.dart`/`subscription_screen.dart`/
`calculators_screen.dart`; Step 6 touches a new `lib/features/trends/` directory plus
`summaries_api.dart`/`summaries_provider.dart` — disjoint files). Steps 7 and 8-9 (Phase 3) are fully
independent of Phases 1-2 and can run in parallel with them if capacity allows, though
sequential is fine given this is a solo effort.

---

## Step 1 — Global page transitions + tab-switch fade

**Type:** Flutter UI, theming. **Model:** default. **Independent — no dependency on other
steps.**

**Context brief:** Two distinct mechanisms, don't conflate them (see Grounded section
above). This step delivers both, as two clearly separated pieces of work: (a) a
`PageTransitionsTheme` override in `AppTheme.light()`/`AppTheme.dark()` that upgrades
every push/pop navigation in the app (go_router's default page wrapper *and* the
existing `Navigator.push(MaterialPageRoute(...))` calls in `placeholder_screens.dart`)
from the plain Android/iOS platform default to something more deliberate — e.g.
`SharedAxisPageTransitionsBuilder`-style forward/backward motion. Since `pubspec.yaml`
has no `animations` package today, either add it (small, well-maintained Google package,
no other dependency conflicts expected) or hand-roll a `PageTransitionsBuilder` subclass
using `SlideTransition`/`FadeTransition` if avoiding a new dependency is preferred —
decide based on what `flutter pub deps` shows for conflicts, default to adding the
package if none. (b) A tab-switch fade: wrap `navigationShell` in `app_shell.dart` with a
lightweight custom transition (e.g. an `AnimatedSwitcher`-style cross-fade or a manual
`AnimatedOpacity` driven off `navigationShell.currentIndex` changes) — must preserve each
branch's own navigator stack exactly as `StatefulShellRoute.indexedStack` already does
(don't rebuild branches on tab switch, only animate the visual transition). All motion
must route through `AppMotion`'s existing tokens (`lib/core/theme/app_motion.dart`) and
respect `context.reducedMotion`, matching how every other animation in this app already
behaves (chatbot, lock-screen, login-shake, the recent onboarding tour).

**Task list:**
1. In `lib/core/theme/app_theme.dart`, add a `pageTransitionsTheme` to both
   `AppTheme.light()` and `AppTheme.dark()`'s returned `ThemeData`, respecting
   `context.reducedMotion` where feasible (a `PageTransitionsBuilder` doesn't have
   direct `BuildContext` access at construction time — check `MediaQuery.disableAnimationsOf`
   inside the builder's `buildTransitions` override instead, which does receive
   `context`).
2. Verify the new transition applies to both call styles without per-route changes:
   spot-check a go_router `GoRoute` push (e.g. `/consent`) and a `Navigator.push
   (MaterialPageRoute(...))` push (e.g. Subscription from Settings) — both should pick
   up the new transition automatically since `MaterialPageRoute` reads
   `Theme.of(context).pageTransitionsTheme`.
3. In `lib/core/router/app_shell.dart`, add the tab-switch fade wrapper around
   `navigationShell` in `AppShell.build()`. Keep `AppShell` correct if
   `context.reducedMotion` is true (skip animation, instant switch).
4. Do not touch `computeRedirect()`'s logic itself in this step — Step 3 is where its
   behavior gets re-verified after these changes, not modified.

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test
```

**Exit criteria:** `flutter analyze` clean, full suite green (no widget test assumed a
specific instant-transition timing that this change breaks — fix any that do rather than
skip them), new transition visibly applies to both a go_router push and a
`Navigator.push` in a manual run, tab switches show a visible but quick cross-fade with
no flash of the wrong branch's content, reduced-motion setting still yields instant
transitions.

---

## Step 2 — Delete the dead Q&A Insights feature

**Type:** Flutter, dead-code removal. **Model:** default. **Independent — touches only
files nothing else depends on.**

**Context brief:** Frees the "Insights" name for Step 6's genuinely new screen and
removes ~350 lines of unrouted, untested-by-use code before it's confused with the new
feature. Confirmed via grep (2026-09-13): nothing outside `lib/features/insights/`
imports any of its symbols; `chatbot_screen.dart:27`'s reference is a doc comment only.

**Task list:**
1. Delete `lib/features/insights/` in full (`data/insights_api.dart`,
   `models/insight.dart`, `providers/insights_provider.dart`,
   `screens/insights_screen.dart`).
2. Delete its three test files: `test/features/insights/data/insights_api_test.dart`,
   `test/features/insights/providers/insights_provider_test.dart`,
   `test/features/insights/screens/insights_screen_test.dart`.
3. Update the doc comments at `lib/features/chatbot/screens/chatbot_screen.dart:15,25-27`
   and `lib/core/router/placeholder_screens.dart:15` that reference
   "still present under `lib/features/insights/`" — remove or rewrite them since the
   code they refer to no longer exists.
4. Re-run a full-repo grep for `features/insights`, `InsightsScreen`, `insightsProvider`,
   `InsightsApi` to confirm zero remaining references before committing.
5. Leave the backend's `insights_router` (`/insights/ask` etc.) untouched — it's a
   separate concern (Pro-tier AI Q&A backend capability) that may still be used by other
   clients or revisited later; this step is Flutter-side dead-code removal only, not a
   backend change.

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
grep -rn "features/insights\|InsightsScreen\|insightsProvider\|InsightsApi" lib/ test/
flutter analyze
flutter test
```

**Exit criteria:** The grep above returns zero matches, `flutter analyze` clean, full
suite green (test count drops by exactly the 3 deleted files' test count, nothing else
regresses).

---

## Step 3 — Live visual QA: transitions + redirect-precedence regression

**Type:** Verification (Flutter, manual + emulator/Chrome DevTools MCP). **Model:**
default. **Depends on Step 1.**

**Context brief:** Two things must both hold after Step 1's changes: the new
transitions look right, and — because `computeRedirect()` governs every screen this app
shows and Step 1 didn't touch its logic but did touch how screens visually appear —
the full redirect chain (`locked > consentsRequired > onboardingRequired > shell`) still
behaves identically. This mirrors the verification rigor the most recent onboarding-tour
work applied to the same redirect chain.

**Task list:**
1. Confirm `test/core/router/app_router_test.dart`'s existing `computeRedirect` test
   table still passes unmodified (it should — Step 1 changes presentation, not
   redirect logic; a failure here means Step 1 accidentally touched something it
   shouldn't have).
2. Live walk, via Chrome DevTools MCP screenshots or an Android emulator, in both light
   and dark mode: a tab switch (e.g. Home → Budgets → Assistant), a go_router push
   (Consent screen re-visit if reachable, or `/onboarding` via a fresh test account),
   and a `Navigator.push` (Settings → Subscription). Confirm each shows the new
   transition, no visual glitches (flashing, wrong-branch flicker), and reduced-motion
   (`Settings → Accessibility` if such a toggle exists, or a forced
   `MediaQuery(disableAnimations: true)` override in a debug harness) yields instant
   transitions with no fade.
3. Confirm the lock-screen escape hatch (from `.claude/PRPs/plans/completed/lock-screen-
   logout-escape-hatch.plan.md`) and the onboarding gate both still route correctly
   end-to-end (lock → unlock → correct next screen; a fresh/incomplete-onboarding
   account still lands on `/onboarding`, not the shell).

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter test test/core/router/
```
Plus the live walk in step 2 above (screenshots, not an automated test).

**Exit criteria:** All router tests green, live walk confirms transitions render
correctly in both themes with no regression to lock/consent/onboarding redirect
behavior, reduced-motion confirmed instant.

---

## Step 4 — Live-verify current L1 dead-space state (research, no code change)

**Type:** Verification / research. **Model:** default. **Independent.**

**Context brief:** `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md` contradicts itself on
whether Notifications' dead-space issue is already fixed (line 118 implies yes, line 129
implies L1 overall is still open). Resolve this before generating any Stitch output —
generating a "fix" for something already fixed wastes a Stitch pass and risks visual
drift from a screen that's already correct.

**Task list:**
1. Run the app (emulator or Chrome DevTools MCP) in light and dark mode, and screenshot
   all four L1 screens as they exist today: `accounts_screen.dart`,
   `notifications_screen.dart`, `subscription_screen.dart`, `calculators_screen.dart`
   (Loan Calculator).
2. For each, judge against the original finding's description ("roughly 50-70% of the
   viewport blank below their content on a tall phone") — note per-screen whether the
   issue is still present, partially addressed, or fully resolved.
3. Save screenshots under `qa_screens/` following the existing naming convention seen in
   that directory, and commit a short findings addendum (a few sentences per screen,
   dated 2026-09-, with the actual date) directly into
   `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md` under the existing L1 entry — a durable,
   greppable artifact, not text living only in a future branch/PR description (which
   doesn't exist yet when this step runs and nothing would ever point back to). Note in
   the same addendum that L2 and L3 already carry explicit "closed, no action" decisions
   in that doc — only L1 is genuinely open; this step's job is finding L1's current
   per-screen state, not re-litigating L2/L3.

**Verification:** Screenshots exist and are reviewed, and the addendum is committed to
the audit doc; no automated test applies to this research step.

**Exit criteria:** A clear, current, per-screen "still open / already fixed" verdict for
all four L1 screens, committed as an addendum in
`docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`, replacing the audit doc's
self-contradictory text as the source of truth for Step 5's scope.

---

## Step 5 — Stitch: fix confirmed-open L1 dead-space screens

**Type:** Flutter UI + Stitch MCP. **Model:** default. **Depends on Step 4.**

**Context brief:** Use `mcp__stitch__*` tools (e.g. `generate_screen_from_text` or
`edit_screens` against an existing screen) with `docs/stitch-design-brief.md` uploaded
as the design-system input per its own §9 instruction — don't regenerate the palette/
typography rules per screen. Only touch the screens Step 4 confirmed are still open.
The suggested direction from the original audit (vertically center short lists, or add
a secondary module) is a starting point, not a mandate — use whichever reads best in
the actual Stitch output, composed from existing `lib/shared/widgets/` components.
**Before uploading the brief to Stitch, fix line 136**: it still lists the 5-tab nav as
"Home, Invest, Budgets, **Insights**, Settings," but the live shell has replaced that
4th slot with Assistant (`app_shell.dart:22`, `DESIGN.md`'s own Navigation section).
Uploading the brief uncorrected would tell Stitch to design against a nav that no
longer exists.

**Task list:**
1. Correct `docs/stitch-design-brief.md:136`'s tab list to match the live shell
   (Home, Invest, Budgets, Assistant, Settings) before generating anything.
2. For each screen Step 4 confirmed still has the dead-space issue, generate a revised
   layout via Stitch, informed by `docs/stitch-design-brief.md` and the existing
   component library.
3. Implement the accepted design in the corresponding Dart file, reusing
   `lib/shared/widgets/` components rather than introducing new one-off widgets, unless
   the design genuinely needs a new small reusable component (in which case add it to
   `lib/shared/widgets/` following the existing naming/doc-comment conventions there).
4. Verify light and dark mode both render correctly (per `AppSemanticColors` /
   `AppColors` — no hardcoded colors that only work in one theme).

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test
```
Plus live screenshots of the updated screens in both themes.

**Exit criteria:** `flutter analyze` clean, full suite green, each fixed screen no
longer shows the dead-space issue in a live screenshot, light and dark mode both
correct, no new one-off widget style introduced where an existing shared widget would
do.

---

## Step 6 — Stitch: new Trends analytics screen

**Type:** Flutter UI + Stitch MCP + minor API client extension. **Model:** strongest
(genuine information-architecture design work, per the brief's own note that "the actual
information architecture here is wide open"). **Depends on Step 4 (shared vocabulary
confirmed live) only** — the earlier draft of this plan also listed a dependency on
Step 2, reasoning that Step 2 "frees the name" for reuse here; that's now moot because
this step deliberately does **not** reuse the name "Insights" (see below), so Step 6 can
start as soon as Step 4 lands, in parallel with Step 2/3/5 if useful.

**Context brief:** Per `docs/stitch-design-brief.md` §8 (lines 273-279): a trends
dashboard covering net-worth-over-time, spending-pattern callouts, and budget-adherence
trends, built from the existing hero-metric-card/progress-card/stat-strip vocabulary
(the brief explicitly says not to invent a fourth visual language). All three data
sources already exist server-side in `summaries_router` — this is a client-only build.
Reached from the Dashboard tab via a tappable entry point (card/tile), not a new bottom-
nav destination (see "No 6th nav tab" in the Grounded section).

**Naming — deliberately NOT `lib/features/insights/`.** The backend keeps a live,
separate `/insights` Q&A router (`insights_router`, mounted in
`piggybank-backend/backend/app/api/router.py`) that Step 2 does not touch (Step 2 is
Flutter-only dead-code removal). A new Flutter feature named `insights/` that actually
calls `/summaries/*` would recreate the exact naming confusion this plan exists to
remove, just with the backend route now pointing at something unrelated to the Flutter
folder of the same name. Use `lib/features/trends/` instead.

**Budget-adherence trend needs more than one API call.** `get_budget_usage` in
`summaries/router.py` takes a **required** `month: str` and returns a single month's
usage — there is no existing "trend" endpoint. A trend view means fanning out N calls
(e.g. the trailing 6 months) client-side and assembling the series in Flutter; this step
does not add a new backend endpoint (out of scope, per the Explicitly out of scope
section), it composes the existing single-month one N times.

**Task list:**
1. Extend `lib/features/summaries/data/summaries_api.dart` with `budgetUsage({required
   String month})`, `recurringExpenses()`, and `highCostExpenses()` methods, mirroring
   the existing `netWorth()`/`cashflow()`/`netWorthHistory()` methods' structure exactly
   (same try/catch → `ApiClient.errorFrom(e)` pattern, same model-parsing style). Add
   corresponding model classes to `lib/features/summaries/models/summaries.dart` if
   they don't already partially exist there — check the file first.
2. Extend `lib/features/summaries/providers/summaries_provider.dart` with providers for
   the new API calls. `budgetUsage` needs a provider **family** (keyed by month) so the
   trend view can fetch a rolling window (default: trailing 6 months) with one provider
   call per month, matching whatever family-provider pattern already exists elsewhere in
   this codebase — check for a precedent before inventing the pattern fresh. Define what
   a month with no budget set at all returns (an explicit zero/empty state per month,
   not an error) before wiring the UI to it.
3. Correct `docs/stitch-design-brief.md:136`'s stale tab list first if Step 5 hasn't
   already done so (both steps read the same brief — fix it once, whichever step lands
   first).
4. Design the new screen via Stitch, informed by `docs/stitch-design-brief.md` §8 and
   the existing component library. Expect multiple Stitch variations per the brief's
   §9 instruction for "new — no precedent" screens; pick the one that best composes
   `HeroMetricCard` (net worth trend), `ProgressCard` (budget adherence), and a stat-
   strip pattern (spending-pattern callouts) — check
   `lib/features/dashboard/screens/dashboard_screen.dart`'s `_CashflowStatStrip` for the
   exact stat-strip pattern already established there.
5. Implement the accepted design as a new screen file, e.g.
   `lib/features/trends/screens/trends_screen.dart`, under a fresh `lib/features/trends/`
   directory (data/models/providers/screens sub-folders, matching this codebase's
   per-feature layout convention).
6. Add the Dashboard entry point (card/tile) that navigates to the new screen via
   `Navigator.push` (matching how `account_detail_screen.dart` is already reached from
   Accounts), not a new `GoRoute`/shell branch.
7. Verify light and dark mode both render correctly, and that loading/error/empty states
   for each of the data sources are handled (reuse `state_views.dart`'s
   `InlineError`/`EmptyState` patterns, matching `BudgetsBody`'s existing
   `AnimatedSwitcher`-over-`AsyncValue.when` structure).

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test
```
Plus live screenshots of the new screen (populated, loading, error, and empty states)
in both themes, and a manual check that the Dashboard entry point navigates correctly.
Note: `test/features/summaries/` does not exist yet in this codebase (confirmed via
adversarial review) — this step creates that test directory rather than following an
existing pattern inside it; base its structure on the closest analogous feature's test
layout (e.g. `test/features/budgets/` or `test/features/dashboard/` if one exists).

**Exit criteria:** `flutter analyze` clean, full suite green (plus new tests for the
new screen, the new provider family, and the new `SummariesApi` methods), the new screen
renders real multi-month data end-to-end against the backend's existing `summaries`
endpoints, no new bottom-nav destination added, no duplicate "ask a question"
functionality re-introduced (that remains solely the Assistant tab's job), and no
Flutter feature or route named "insights" reintroduced anywhere.

---

## Step 7 — Backend: `GET /api/updates/latest`

**Type:** Python/FastAPI + one Docker Compose change. **Model:** default. **Independent
— no dependency on Flutter steps.**

**Context brief:** Follows the exact module-per-domain pattern documented in
`piggybank-backend/CLAUDE.md` and visible in `backend/app/api/router.py`. Reads the
already-written `downloads/latest.json` (produced by `scripts/publish_release.sh`,
untouched by this step) and returns it as a typed response, plus a `downloadUrl`.

**Two corrections from adversarial review — read before starting:**
1. **The `backend` container cannot see `downloads/` today.** `docker-compose.yml`
   mounts `./downloads:/srv/downloads:ro` into the **`caddy`** service only; the
   `backend` service has no such bind mount, and `backend/app/config.py` has no
   `downloads`-path setting at all. "No other backend file needs touching" (an earlier
   draft's claim) is wrong — this step must add
   `- ./downloads:/srv/downloads:ro` to the `backend` service in `docker-compose.yml`
   (mirroring Caddy's existing mount exactly) and add a `downloads_dir` setting to
   `config.py` (default `/srv/downloads`, overridable for local/non-Docker dev). This
   is a deploy-affecting change: the backend container needs recreating (`docker compose
   up -d --build`), not just a code reload, for the mount to take effect — call this out
   explicitly in the PR description since it's easy to miss in a routine "restart" deploy.
2. **`downloadUrl` cannot be derived from the request's own Host.** The API is reached
   directly on `:8000` (`docker-compose.yml`'s `BACKEND_PORT` mapping), but
   `/downloads/*` is served separately by **Caddy on :80** (`Caddyfile`'s
   `handle_path /downloads/*` block) — deriving `downloadUrl` from the incoming
   request's host would produce `http://<host>:8000/downloads/...`, which the backend
   itself does not serve and which doesn't exist. Build `downloadUrl` from an explicit
   configured base instead: add a `download_base_url` setting to `config.py` (e.g.
   default `http://tiaanbossies-h81m-ds2.tail886b94.ts.net/downloads`, overridable via
   env var), and construct `downloadUrl = f"{settings.download_base_url}/{filename}"`.
   Do not attempt to infer it from the request.

**Task list:**
1. In `docker-compose.yml`, add `- ./downloads:/srv/downloads:ro` to the `backend`
   service's `volumes:` list.
2. In `backend/app/config.py`, add `downloads_dir` (default `/srv/downloads`) and
   `download_base_url` (default `http://tiaanbossies-h81m-ds2.tail886b94.ts.net/downloads`)
   settings.
3. Create `backend/app/updates/` with `router.py` and `schemas.py`, following the shape
   of a small existing module (check `backend/app/` for the simplest precedent to
   mirror).
4. `schemas.py`: a Pydantic model matching `latest.json`'s fields (`version: str`,
   `buildNumber: str`, `filename: str`, `publishedAt: str`) plus a computed
   `downloadUrl: str`.
5. `router.py`: `GET /latest` reads `latest.json` from `settings.downloads_dir`, returns
   404 if the file doesn't exist yet (fresh install with no release published),
   otherwise parses it and returns it with `downloadUrl` built from
   `settings.download_base_url` + `filename` (never from the request). Apply the
   existing `limiter` (slowapi, already wired in `limiter.py`/`main.py` for other
   routes) to this endpoint — it's unauthenticated by design, so it should have the same
   rate-limit discipline as other unauthenticated surfaces in this app. Return only
   `filename`, never a server filesystem path.
6. In `backend/app/api/router.py`, add `from ..updates import updates_router` and
   `api_router.include_router(updates_router, prefix="/updates", tags=["updates"])`,
   matching the existing one-line-per-module pattern exactly.
7. Add a test file `backend/tests/test_updates.py` (check `backend/tests/` for the
   existing test-naming and fixture conventions — likely a `TestClient` + a temp
   `latest.json` fixture, using `downloads_dir` override rather than the real
   `/srv/downloads` path) covering: file present → 200 with correct fields incl. a
   correctly-built `downloadUrl`; file absent → 404; rate limit applied.

**Exposure note for the cross-cutting security review:** this endpoint is
**unauthenticated by design but tailnet-only by construction** (per the Caddyfile/
`docker-compose.yml`'s existing, deliberate Tailscale-only binding for this whole
class of traffic) — not "a new public endpoint" in the internet-facing sense. State
this explicitly in the PR so a reviewer doesn't over-harden it (e.g. by adding auth
that would break the simple "check for updates" flow) or, conversely, misread "tailnet-
only" as "doesn't need the rate limiter."

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\piggybank-backend\backend"
ruff check .
pytest tests/test_updates.py -v
pytest
```
Plus, after `docker compose --env-file .env.docker up -d --build` in a local/staging
compose environment: `curl http://localhost:8000/api/updates/latest` against a real
mounted `downloads/latest.json`, confirming the container can actually read the file
(this is the part the automated tests can't catch, since they'll use a config override
rather than the real mount).

**Exit criteria:** `ruff check .` clean, new tests green, full backend suite green (no
regression), the `backend` container's compose mount confirmed working (not just the
code path), `downloadUrl` in the response resolves to a real, reachable file via Caddy
on :80 — not the backend's own :8000.

---

## Step 8 — Flutter: Tailscale domain switch + update-check banner

**Type:** Flutter, networking + UI. **Model:** default. **Depends on Step 7** (needs a
live endpoint to test the real response shape against, though local development against
a stubbed response can start in parallel).

**Context brief:** Two changes in one step because they're related but small: (a) the
confirmed "domain everywhere" decision — swap `api_config.dart`'s hardcoded IP for the
Tailscale MagicDNS domain; (b) the update-check itself, reusing `about_screen.dart`'s
existing `PackageInfo.fromPlatform()` pattern for the "current version" side of the
comparison.

**Task list:**
1. In `lib/core/api/api_config.dart`, change `defaultValue` from
   `'http://100.121.165.7:8000/api'` to
   `'http://tiaanbossies-h81m-ds2.tail886b94.ts.net:8000/api'`. **Port confirmed correct
   by adversarial review**: `docker-compose.yml` maps
   `${BACKEND_BIND:-0.0.0.0}:${BACKEND_PORT:-8000}:8000`, and `.env.docker.example` sets
   `BACKEND_BIND=100.121.165.7` — MagicDNS resolves the domain to that same tailnet IP,
   so `:8000` hits the identical bound socket either way; Caddy is not in the API
   request path at all (only `/downloads/*` goes through Caddy on :80). **Two caveats to
   verify, not assume:** (a) confirm the real production `.env.docker` (not just
   `.env.docker.example`) actually still has `BACKEND_BIND=100.121.165.7` before
   relying on this — it's a live server config file this plan doesn't read; (b)
   MagicDNS resolution can fail in situations where the raw IP still works (DNS-only
   networks, tailnet propagation delays) — `publish_release.sh` itself already carries
   an IP fallback for exactly this reason, but this Flutter change does not add one.
   Consider whether `ApiConfig` should try the MagicDNS domain first and fall back to
   the raw IP on connection failure, or accept the simpler single-address change for now
   and note the fallback as a fast, low-risk follow-up if the domain proves flaky in
   practice — decide based on how critical uninterrupted access is versus shipping
   sooner. **Rollback note:** because this change affects every network call in the
   app, keep the previous IP-based value in a comment or easily-referenced commit so a
   revert is a one-line change if the domain turns out to be unreliable. Update the doc
   comment above it to reflect the new default and keep the `--dart-define` override
   documented as-is.
2. Add an `UpdatesApi` client (new small file, e.g.
   `lib/core/api/updates_api.dart` or under a new `lib/features/updates/` directory —
   match whichever convention this app uses for a feature this thin; check if other
   single-endpoint features exist as a precedent) calling `GET /updates/latest`,
   returning a small model (`version`, `buildNumber`, `downloadUrl`, `publishedAt`).
3. Add a provider that fetches this on app launch (or lazily on first Dashboard/Settings
   visit — decide based on where `about_screen.dart` and the app's launch sequence
   already do similar one-shot fetches) and compares `buildNumber` (more reliable than
   semver `version` string comparison) against `PackageInfo.fromPlatform()`'s
   `buildNumber`.
4. When the remote `buildNumber` is numerically greater, show a dismissible banner
   (Dashboard, or a `SnackBar`/banner from Settings → About, matching this app's
   existing `ConfirmDialog`/`state_views.dart` visual language) with the new version
   number and a link that opens `downloadUrl` in the platform browser (`url_launcher` —
   check `pubspec.yaml` for whether it's already a dependency before adding it; likely
   already present given the app links out elsewhere — verify for *this* app
   specifically).
5. Do not persist a "dismissed until next version" flag unless explicitly desired —
   default to re-showing on next launch if still out of date, since this is a manual,
   low-frequency check (confirm this default is acceptable; it's a minor UX call, not an
   architectural one).

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test
```
Plus a manual run pointed at the Step 7 endpoint (via `--dart-define=API_BASE_URL=...`
if testing against a local backend, or the real Tailscale domain if testing from a
device on the tailnet) confirming the banner shows for an older local build number and
stays hidden for a current/newer one.

**Exit criteria:** `flutter analyze` clean, full suite green, `api_config.dart` points
at the MagicDNS domain by default, banner correctly shows/hides based on a real
comparison against the live endpoint, tapping the download link opens the correct URL,
no in-app download/install code introduced anywhere.

---

## Step 9 — End-to-end update-flow verification

**Type:** Verification. **Model:** default. **Depends on Steps 7 and 8.**

**Context brief:** Confirms the whole chain works together against something close to a
real release, and confirms the Tailscale-only reachability assumption actually holds —
i.e. that this doesn't accidentally become reachable from the public internet, which
would contradict the Caddyfile's explicit design intent.

**Task list:**
1. Either run `scripts/publish_release.sh` for a low-stakes test build (confirm with the
   user before doing this against the real production `downloads/` directory — it's a
   real deploy artifact, not a throwaway), or manually place a synthetic
   `latest.json` + dummy APK file in a local/staging `downloads/` directory for testing
   without touching production.
2. Confirm `GET /api/updates/latest` returns the expected shape against that data,
   accessed via the Tailscale MagicDNS domain (not just `localhost`).
3. Run the Flutter app with three synthetic scenarios (older build number, same build
   number, newer build number) and confirm the banner shows only in the "older" case.
4. Confirm the download link, when tapped, is reachable from a device joined to the
   Tailscale network. **The naive negative check (curling
   `piggybank.fynboscreative.co.za` and expecting failure) proves nothing** — that
   hostname's public DNS points elsewhere entirely, so it was never going to reach this
   server regardless of any config here. The real risk is different: `CADDY_BIND` is
   commented out in `.env.docker.example`, meaning Caddy by default binds `0.0.0.0` on
   :80/:443, and the `{$DOMAIN}` block reverse-proxies **every path** (including
   `/api/*`) to the backend — so if this host's own public IP ever gets pointed at by
   *any* domain (now or by a future DNS change), the API would be reachable over the
   public internet, not just the tailnet, contradicting the Caddyfile's stated intent.
   Do the real check instead: `curl -H "Host: piggybank.fynboscreative.co.za"
   http://<this-server's-actual-public-IP>/api/updates/latest` from a machine outside
   the tailnet, and confirm the host's firewall (not just Caddy's routing) actually
   blocks unsolicited inbound :80/:443 from the public internet — Caddy's own routing
   config is not a substitute for a firewall rule if the real exposure risk here is
   "what happens if DNS ever points here," not "does this specific hostname resolve
   here today."
5. Re-run the `flutter-production-audit` skill (or manually re-verify against
   `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`'s checklist) across all changed screens
   from Steps 1, 5, 6, and 8 together, to confirm nothing regressed once every phase's
   changes are combined on `master`.

**Verification:** Manual, as described above — this step has no new automated test of
its own; it exercises Steps 7-8's existing tests plus live network checks.

**Exit criteria:** Full update-check flow verified end-to-end on a real device over
Tailscale; confirmed non-reachable from outside the tailnet; combined visual audit
across all changed screens shows no new Critical/High findings versus the 2026-09-11
baseline.

---

## Cross-cutting requirements for all steps

- Each step = its own branch + PR, `--no-ff` merge, matching `penny-onboarding-tour`'s
  precedent (push branch, open PR manually via the browser link Git prints, since `gh`
  isn't installed on this machine).
- Run `flutter analyze` + `flutter test` (Flutter steps) or `ruff check .` + `pytest`
  (backend steps) before every merge — no exceptions.
- Use a `flutter-reviewer` pass on Steps 1-3, 5, 6, 8 and a `fastapi-reviewer` pass on
  Step 7 before merging each.
- Security review is required before merging Step 8's `api_config.dart` change (it
  affects every existing network call in the app) and before merging Step 7's new
  endpoint (confirm it leaks nothing beyond version metadata — no internal filesystem
  paths, no auth-bypass surface; it's intentionally unauthenticated but tailnet-only by
  construction, not internet-public — see Step 7's exposure note, and confirm the
  slowapi rate limit is actually applied).
- Use `/save-session` between steps; `/resume-session` to continue across sessions,
  matching how the Penny onboarding tour blueprint was executed across multiple
  sessions.
- After Step 9, the app should still fully clear the quality floor already established
  by `docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md` and this repo's other QA docs — no
  step in this plan should be considered done if it regresses a previously-passing
  finding.
