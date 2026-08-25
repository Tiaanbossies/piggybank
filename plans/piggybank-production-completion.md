# Blueprint: Piggybank Production Completion

**Objective:** Close every gap identified in `docs/production-completion-gap-report.md`
(2026-08-23) to reach genuine production completeness, including Google Play
distribution readiness. Reverses 5 of the 7 items the Phase 8 parity sign-off in
`IMPLEMENTATION_PLAN.md` marked as deliberate v1 exclusions.

**Mode:** Direct (no git remote, no `gh` CLI detected on this machine — edit-in-place,
commit directly to `master`, no branches/PRs).

**Revision note:** This plan went through an adversarial Opus review after its first
draft. That review found 6 CRITICAL issues (wrong server host/credentials assumed for
Step 6, a hidden lock-flow rewrite disguised as a simple toggle in Step 5, a missing
deployment step between backend and client work, an unreachable privacy-policy URL
plan, a broken dependency graph) and several bundling problems. This version fixes all
of them — step count grew from 10 to 15 as a direct result (several steps needed
splitting once their real scope was exposed), which is a **correct** outcome of the
review, not scope creep.

**Explicitly out of scope for this blueprint** (user decisions, see gap report's Open
Questions):
- **Dashboard customization** — dropped. The original "one well-designed fixed layout"
  decision stands, re-confirmed. Correction to the gap report: a `dashboard_widgets`
  JSON column already exists on `User` (`backend/app/models.py`, migration
  `20260518_1000_c6d7e8f9a0b1_add_dashboard_widgets_to_user.py`) — the report's "no
  backend storage exists" claim was wrong, but this doesn't change the drop decision,
  which was about product direction, not backend cost.
- **Admin implementation** — not planned here. Step 0 below is a scoping conversation
  only; concrete Admin build steps get their own blueprint once that conversation
  produces an actual spec. **This is a hard gate, no exceptions** — do not build any
  Admin-adjacent code, however small, until Step 0's spec exists and a new plan covers
  it.
- **Retrofitting tests onto pre-existing untested domains** (`assets`, `auth`,
  `budgets`, `calculators`, `dashboard`, `goals`, `summaries` currently have zero
  tests) — out of scope here; test coverage is a per-step requirement for *new* work
  only in this plan.
- **Instrument Comparison's benchmark overlay (CPI/STeFI), CSV export, and shareable
  URL state** — confirmed low priority in the gap report, matches the web app's own
  "coming soon" status. Not planned in this blueprint; optional future pickup.

**Total steps:** 15 (Step 0 is a conversation; Steps 1–9d are implementation, with
Steps 4/5/9 each split into lettered sub-steps per the review).

---

## Path convention

`Piggybank` and `piggybank-backend` are **sibling directories** under
`C:\Fynbos Creative Master\02_Clients\`, not nested. Every path below is given in full
from that root, or explicitly marked which repo it's relative to — a cold agent
starting inside `Piggybank/` will not find `piggybank-backend/...` via a bare
relative path.

**Correction (2026-08-25):** `finance-app.v3-main` was never the real backend — it was
only a template/scaffold the app was built and tested against. This blueprint's earlier
revisions (and the Steps 4a/4b/5b "done" markers below) were written under that wrong
assumption. `piggybank-backend` (forked from `finance-app.v3-main`'s current code,
full domain scope kept) is now the real, standalone, deployed backend. It's still
backed by the same codebase, so most of what's below stayed accurate after a path swap
— but treat any surviving `finance-app.v3-main` reference in this doc as pointing at a
retired template repo, not a deploy target. `finance-app.v3-main` remains on disk
locally (not deleted) purely as a source for historical `legacy/react-web/` content
(see Step 8's privacy-policy note) — it is not running anywhere.

## Server access note (read this before Step 6 or Step 9c)

**Use `100.121.165.7`, SSH as `mcp` with `~/.ssh/id_ed25519`.** The real backend is now
`piggybank-backend`, deployed to `~/piggybank-backend` on this host (containers prefixed
`piggybank-backend-*`) via tar+scp (not `git pull` — the `mcp` server user has no GitHub
credentials). The old `finance-appv3-*` stack that used to occupy this same host:port
was backed up (`~/finance-appv3-backup-20260825.sql.gz` on the server) and decommissioned
on 2026-08-25 to free port 8000 for the new deployment — the Flutter app's
`api_config.dart` default needed **no change** as a result.

`piggybank-backend/docker-compose.yml`'s Ollama defaults were fixed during the fork (no
more hardcoded jarvis IP/model) — `OLLAMA_BASE_URL` defaults to `http://ollama:11434`,
`OLLAMA_MODEL` to `llama3.1:8b`. `AI_FEATURES_ENABLED=false` on this deployment until
Step 6 is picked up. `finance-app.v3-main/SERVER_CONTEXT.md`'s "jarvis"
(`100.107.227.52`) host reference is doubly stale now — both because that host was
already abandoned, and because `finance-app.v3-main` itself is a retired template, not
a deploy target at all.

---

## Dependency graph

```
Step 0  (Admin scoping conversation) ─────────── independent

Step 1  (RA/TFSA calculator) ──────────────────── independent

Step 2  (Settings: Subscription + Import history)
        │
        ▼
Step 3  (Settings: Appearance)                    ← depends on Step 2 (creates
                                                     test/features/settings/, which
                                                     Step 3's own test command needs)

Step 4a (Backend: PIN/Security schema) ─────────┐
Step 4b (Backend: Notification prefs schema) ───┤  independent of each other,
        │                    │                   │  both independent of Steps 1-3
        ▼                    ▼
Step 5a (Settings: Security  Step 5b (Settings: Notifications
         screen, depends            screen, depends on 4b)
         on 4a)

Step 6  (AI infra: Ollama + AI_FEATURES_ENABLED) ── independent of Steps 1-5
        │
        ▼
Step 7  (Insights tab UI)
        │
        ▼
Step 8  (Chatbot UI)

Step 9a (Signing + .gitignore + gradle wiring) ──── independent of everything
Step 9b (Launcher icons)  ──────────────────────── independent of everything
Step 9c (Privacy policy, separate static host) ──── independent of everything
Step 9d (Store listing assets/copy) ──────────────── depends on Steps 1-8
                                                       (needs a feature-complete app
                                                       to screenshot)
```

**Recommended execution order:** 0 → 1 → 2 → 3 → 4a → 5a → 4b → 5b → 6 → 7 → 8 →
9a → 9b → 9c (any time) → 9d (last).

---

## Step 0 — Admin scoping conversation ✅ DONE (2026-08-23)

**Outcome:** `Piggybank/docs/admin-scope.md`. Admin is scoped for a single developer
(not a support team), with 4 confirmed features: price-refresh trigger (already
built), user lookup/management (no hard-delete via UI), subscription overrides
(audit-logged), and a usage-metrics dashboard (aggregate counts only, explicitly not
APM/error tracking). Implementation is a separate future blueprint — this step only
unblocked planning, it didn't build anything.

**Type:** Conversation, not code. **Model:** default.

**Context brief:** The backend's `admin` router has exactly one endpoint
(`POST /admin/refresh-prices`, admin-role-gated, triggers a background ticker-price
refresh job) and nothing else. No mockup, no design doc, no prior product decision
describes what an admin panel should contain.

**Task list:**
1. Ask the user directly: who is "the admin" here? What tasks would they actually need
   day-to-day — user lookup/management, subscription overrides, usage metrics,
   triggering the existing price-refresh job, content/data moderation?
2. Once a real feature list exists, determine what new backend endpoints are needed.
3. Write the outcome as a new section in `Piggybank/DESIGN.md` or a dedicated
   `Piggybank/docs/admin-scope.md`.

**Verification:** N/A.

**Exit criteria:** A written, concrete Admin feature spec exists in the repo. **Hard
gate, no exceptions:** do not start any Admin implementation work — not even a "small"
piece slotted into another step — until this spec exists and its own build plan is
written.

---

## Step 1 — RA/TFSA "growth projection" calculator

**Type:** Flutter, client-only. **Model:** default.

**Context brief:** Despite its name, this was never meant to be a real historical
backtest — `Piggybank/DESIGN.md` says so explicitly, and the legacy web equivalent
(`finance-app.v3-main/legacy/react-web/src/pages/TfsaPage.tsx`) is a trivial
client-side constant-rate compounding projection with a "not a forecast, not financial
advice" disclaimer. No backend work needed. The existing convention for pure
calculation logic is `Piggybank/lib/core/calc/` (already holds `loan_calc.dart`, 65
lines, tested at `Piggybank/test/core/calc/loan_calc_test.dart`) — put the new function
there, not inside a feature directory, matching that precedent exactly.
`Piggybank/lib/features/ra/` and `Piggybank/lib/features/tfsa/` already exist as full
features with their own screens — the projection UI belongs as a card/action *within*
those existing RA/TFSA screens (where a user is actually looking at their RA/TFSA
balance), not bolted onto the generic Calculators tab, since the feature is specifically
about RA/TFSA growth, not loans.

**Task list:**
1. `lib/core/calc/growth_projection.dart` — pure function (rate, years, monthly
   contribution → projected value), porting the same math as `TfsaPage.tsx`'s
   reference implementation, not reinvented.
2. Unit tests at `test/core/calc/growth_projection_test.dart` covering: zero
   contribution, zero rate, a normal compounding case, and the 0-years edge case.
3. Add a "Growth projection" card/action to `lib/features/ra/screens/` and
   `lib/features/tfsa/screens/` (check current screen structure first — this may be
   one shared card widget used by both, given RA and TFSA already share structural
   patterns per this session's prior work porting RA "as a structural port of TFSA").
4. Include the "not a forecast, not financial advice" disclaimer, matching the legacy
   reference's framing.
5. Widget test confirming the card renders and computes correctly for at least one
   input.

**Verification:**
```bash
flutter analyze
flutter test test/core/calc/ test/features/ra/ test/features/tfsa/
```
Manual: open an RA or TFSA screen, trigger the growth projection card, verify a sane
result for a hand-verified input (e.g. R1000/month, 10 years, 8%).

**Exit criteria:** `flutter analyze` clean, new tests pass, manual smoke check confirms
correct math.

---

## Step 2 — Settings: Subscription + Import history screens

**Type:** Flutter, client-only (backend already ready). **Model:** default.

**Context brief:** Both backend endpoints already exist and are fully functional —
`GET /api/subscriptions/`, `POST /api/subscriptions/upgrade`/`/cancel`
(`piggybank-backend/backend/app/subscriptions/router.py`), and `GET /api/imports/`
list-with-status (`piggybank-backend/backend/app/imports/router.py`).

**Naming mismatch flagged (2026-08-25, not yet resolved):** the Piggybank Flutter client's
`lib/features/settings/data/subscription_api.dart` calls **singular** `/subscription`,
`/subscription/upgrade`, `/subscription/cancel`, while the backend router above is
**plural** `/subscriptions/...`. Verify the actual route table
(`piggybank-backend/backend/app/subscriptions/router.py`) before wiring this screen up —
one side is wrong and needs fixing, but which side wasn't determined during research.
`Piggybank/docs/stitch-design-brief.md` §8 is the **authoritative** design reference
for both screens (not `docs/ui-ux-mockup-brief.md`, which predates it and is not being
kept in sync — use the stitch brief going forward and note this explicitly wherever a
doc-comment currently points at the older file). `SettingsScreen` in `lib/core/router/
placeholder_screens.dart` currently has a comment refusing to add non-functional rows —
this step makes two of those rows real. Follow the same `Navigator.push` pattern
already used for "Privacy & consent" (added earlier this session) as the template.

**Task list:**
1. `lib/features/settings/data/subscription_api.dart` — wraps `GET /`, `POST
   /upgrade`, `POST /cancel`, mirroring `ConsentsApi`'s structure
   (`lib/features/consent/data/consents_api.dart`).
2. `lib/features/settings/screens/subscription_screen.dart` — tier display,
   upgrade/cancel CTA, using the existing `GroupCard`/`GroupRow` pattern.
3. `lib/features/settings/data/import_history_api.dart` — wraps `GET /api/imports/`.
4. `lib/features/settings/screens/import_history_screen.dart` — row-card list with
   status pills. The existing status-pill widget (`_StatusBadge`, currently
   private/file-local in `lib/features/imports/screens/imports_screen.dart:428`,
   alongside a sibling `_ConfidenceBadge`) needs to be **extracted** to `lib/shared/
   widgets/` (alongside `group_card.dart`/`paywall_dialog.dart`) and both existing call
   sites (`imports_screen.dart:382` and `:500`) updated to import it from there — this
   is a small refactor, not a drop-in reuse, budget for it.
5. Add both as rows to `SettingsScreen`, update its doc-comment to drop these two from
   the "not yet real" list and to cite `stitch-design-brief.md` §8 instead of the older
   mockup-brief. Leave "Profile" alone — it stays an existing non-tappable display row,
   not a sub-screen this plan builds; don't imply otherwise in the doc-comment edit.
6. Tests: API wrapper tests mirroring `consents_api_test.dart`'s fake-adapter pattern,
   widget test per new screen.

**Verification:**
```bash
flutter analyze
flutter test test/features/settings/ test/features/imports/
```
Manual: log in, open Settings → Subscription (confirm tier shows correctly against the
live backend), → Import history (confirm past imports show with correct status).

**Exit criteria:** Both screens reachable and correct against live data,
`flutter analyze`/`flutter test` clean.

---

## Step 3 — Settings: Appearance screen

**Type:** Flutter, client-only, no backend. **Model:** default. **Depends on:** Step 2
(creates the `lib/features/settings/` directory and `test/features/settings/` path this
step's verification command targets — do not attempt this step first).

**Context brief:** `AppTheme.light()`/`AppTheme.dark()` already exist and are wired
into `MaterialApp.router` in `lib/app.dart`. What's missing is user control over
`themeMode` (currently implicit `ThemeMode.system`, no override). `shared_preferences`
is **not currently a dependency** — this step adds it (prefer it over
`flutter_secure_storage`, which is already a dependency but is overkill/wrong-tool for
a non-sensitive UI preference).

**Task list:**
1. `flutter pub add shared_preferences` — confirm it resolves cleanly.
2. Add a `themeModeProvider` (Riverpod, matching existing provider patterns in
   `lib/core/`) backed by `shared_preferences`.
3. Wire its value into `lib/app.dart`'s `MaterialApp.router` `themeMode:` param.
4. `lib/features/settings/screens/appearance_screen.dart` — three-way selector
   (Light/Dark/System), row-card/radio pattern.
5. Add as a Settings row.
6. Tests: provider test confirming persistence round-trips; widget test for selector.

**Verification:**
```bash
flutter analyze
flutter test test/features/settings/ test/core/
```
Manual: change theme, force-close/reopen, confirm persistence and correct rendering —
this is also the first real test of dark mode (unconfirmed against any mockup per
`DESIGN.md`) across a few screens; check Dashboard/Settings/Accounts specifically.

**Exit criteria:** Theme choice persists across restarts, no visual breakage in any of
the three modes on the screens checked.

---

## Step 4a — Backend: PIN/Security schema ✅ DONE (deploy confirmed 2026-08-25)

**Re-verified against `piggybank-backend` (2026-08-25, follow-up session):** the code was
never lost — it was already part of `finance-app.v3-main`'s current backend code, which
`piggybank-backend` was forked from — only re-deployed and re-checked. `alembic current`
on the new deployment shows head `b4c5d6e7f8a9` (past both this migration and Step 4b's),
and a fresh register→login→`/auth/me` round trip confirmed `has_pin` is present in the
response shape.

**Outcome:** Code + migration (`a3b4c5d6e7f8_add_pin_hash_to_user.py`) were already deployed
prior to this session (server's `alembic current` showed `a3b4c5d6e7f8` before any Step 4b
work this session, confirming task 4's deploy had already happened). Re-confirmed live during
this session's Step 4b deploy pass.

**Type:** Backend (FastAPI/Python), `piggybank-backend`. **Model:** strongest
(Opus) — genuine security design, not a mechanical addition.

**Context brief:** No server-side PIN exists today — the current biometric lock
(`local_auth`) is entirely client-side. This adds a PIN as an *additional*, optional
unlock method, reusing the existing argon2id/`pwdlib` password-hashing scheme
(`piggybank-backend/backend/app/security.py`) — do not invent new hashing.

**Task list:**
1. Add `pin_hash` (nullable) to the `User` model (`backend/app/models.py`) — new
   Alembic migration, nullable so existing users are unaffected. **Write a working
   `downgrade()`** — this plan's own git-safety norms require it, and it wasn't
   optional in the original draft even though it wasn't said explicitly. Back up the
   deployed database before applying this migration to the live server in task 4 below
   (`pg_dump` via the existing `make shell-db` access pattern, or equivalent).
2. New endpoints — read `backend/app/auth/router.py` first to decide whether these
   belong there or in a new `security/` domain: `POST` set/change PIN (requires
   re-auth via password or a valid token, argon2id-hashed), `POST` verify PIN
   (rate-limited via the existing `limiter.py` pattern), `DELETE` remove PIN.
3. Backend tests in `backend/tests/`, following `test_auth.py`'s existing patterns, for
   PIN set/verify/rate-limit. Note: `backend/app/limiter.py` disables rate limiting
   under `APP_ENV=test` by design (`enabled=os.getenv("APP_ENV", "development") !=
   "test"`) — the rate-limit test needs an explicit env override to actually exercise
   the limiter, don't write a test that silently can't fail.
4. **Deploy this migration** — this is a real step, not implied by "write the
   migration." SSH to `100.121.165.7` (see Server access note above), transfer the
   updated backend code (same `git ls-files | tar` → `scp` → extract pattern used for
   Phase 7's initial deploy), then `docker compose --env-file .env.docker exec backend
   alembic upgrade head` (equivalent to this repo's `make migrate` target), then
   confirm the new endpoints respond (a quick authenticated `curl` against the new PIN
   endpoints is sufficient — full functional testing happens client-side in Step 5a).

**Verification:**
```bash
cd piggybank-backend/backend
ruff check .
pytest tests/test_auth.py            # full existing suite — regression check,
                                       # run WITHOUT a -k filter that would exclude it
pytest tests/ -k "pin"                # new PIN-specific tests, run separately
```
Then the deploy verification from task 4 above (live `curl` check).

**Exit criteria:** Migration applies cleanly locally AND on the deployed server (task
4 completed, not just written), existing auth tests still pass unfiltered, new PIN
tests pass, `ruff check .` clean.

---

## Step 4b — Backend: Notification preferences schema ✅ DONE (2026-08-25)

**Re-verified against `piggybank-backend` (2026-08-25, follow-up session):** same situation
as Step 4a — the migration/endpoint code was already part of the codebase `piggybank-backend`
forked from, so only a fresh deploy + re-check was needed, not re-implementation. Confirmed
`notification_preferences` present (as `null` on a fresh user) in a live `/auth/me` response.

**Outcome:** Server was found back online this session (`tailscale status`, `100.121.165.7`
reachable again after being offline). Code (commit `b7ca8b0`) reused the `dashboard_widgets`
precedent exactly — no dedicated route, `notification_preferences` exposed via existing
`GET`/`PATCH /auth/me`. Deployed: `git ls-files backend | tar` → `scp` → extracted into
`~/finance-app.v3/backend` on the server → `docker compose up -d --build backend` →
`alembic upgrade head` (server moved `a3b4c5d6e7f8` → `b4c5d6e7f8a9`, matching local head).
Verified live via the deployed `/openapi.json`: `UserOut` schema now includes
`notification_preferences` alongside `dashboard_widgets`/`has_pin`. Local verification before
deploy: `ruff check .` clean on touched files (20 pre-existing errors elsewhere, unrelated),
`pytest tests/test_auth.py` 46/46, `pytest -k "pin or notification"` 19/19.

**Type:** Backend (FastAPI/Python), `piggybank-backend`. **Model:** default (this one
turned out to be simple once the right precedent was found — no longer needs Opus).

**Context brief:** No notification-preference storage exists today. **Reuse the
existing pattern** — `User` already has a `dashboard_widgets: Mapped[list[str] | None]
= mapped_column(JSON, nullable=True)` column (migration
`20260518_1000_c6d7e8f9a0b1_add_dashboard_widgets_to_user.py`) for exactly this shape
of problem (a small, fixed preference set). Follow that precedent directly rather than
re-deriving the JSON-column-vs-table decision from scratch. Notifications themselves
(push delivery) are explicitly **not** in scope — this is preference *storage* only, no
FCM/APNs integration exists anywhere in this codebase and adding one is a separate,
much larger undertaking not implied by "Notifications settings screen."

**Task list:**
1. Add `notification_preferences: Mapped[dict | None] = mapped_column(JSON,
   nullable=True)` to `User`, new Alembic migration (nullable, low-risk — but still
   write a working `downgrade()`, same standard as Step 4a).
2. `GET`/`PATCH` endpoints for the preference dict.
3. Backend tests for round-trip get/patch.
4. Deploy — same process as Step 4a task 4 (can be combined into the same deploy pass
   if done in the same session, since both are small, independent migrations).

**Verification:**
```bash
cd piggybank-backend/backend
ruff check .
pytest tests/ -k "notification"
```
Plus the same live deploy verification as Step 4a.

**Exit criteria:** Migration applied (locally and on the deployed server), tests pass,
`ruff check .` clean.

---

## Step 5a — Settings: Security screen

**Type:** Flutter. **Model:** strongest (Opus) — this step was originally scoped as a
simple UI toggle over "existing local state." **There is no such existing state.**
**Depends on:** Step 4a.

**Context brief — read carefully, this is where the original draft understated the
work:** `lib/core/auth/secure_storage.dart` persists only the refresh token. `lib/
core/auth/auth_controller.dart` has `unlockWithBiometrics()`/`lockApp()` but **no
enable/disable preference** — the app currently locks unconditionally on session
restore (`locked: true`), and `unlockWithBiometrics()` silently sets `locked: false`
whenever `canCheckBiometrics`/`isDeviceSupported` are both false (i.e., a device with
no biometric hardware effectively has no lock at all today, silently). This step must:
(a) add genuinely new persisted lock-preference state, not just read something that
exists; (b) integrate with the `/lock` redirect logic in `app_router.dart` (already
covered by `test/core/router/app_router_test.dart` — extend it, don't fork it); (c)
**never leave the app in a state with zero working unlock methods** — if a user
disables biometrics and hasn't set a PIN, the app must either refuse to disable
biometrics, or fall back to password-based unlock (check whether `local_auth`'s
`authenticate(biometricOnly: false)` already provides an OS-level device-credential
fallback — if so, that may already cover this case; verify, don't assume). This is
exactly the code this session's own notes flag as "hardened this session... treat any
regression here as high-severity" (the `FlutterFragmentActivity`/`USE_BIOMETRIC` fix)
— proceed with real caution, not a routine toggle mentality.

**Task list:**
1. Design the lock-preference state model first (a short written note in the PR/commit
   description is enough — don't skip straight to code given the "never zero unlock
   methods" invariant above).
2. `lib/features/settings/data/security_api.dart` — wraps Step 4a's PIN endpoints.
3. New persisted preference (biometric enabled/disabled — likely `shared_preferences`,
   consistent with Step 3's choice for non-secret local prefs) plus the actual
   integration into `auth_controller.dart`'s lock logic.
4. `lib/features/settings/screens/security_screen.dart` — biometric toggle, "Change
   PIN" flow (set/change/remove via Step 4a's endpoints).
5. Extend `test/core/router/app_router_test.dart` for any new redirect-relevant state
   this introduces (only if the lock logic actually changes redirect behavior — if the
   toggle is purely "which unlock method is offered on the existing `/lock` screen," no
   redirect changes may be needed; confirm before assuming a change is required).
6. Widget tests for the new screen; a specific test proving the "never zero unlock
   methods" invariant holds (e.g., attempting to disable biometrics with no PIN set is
   blocked or auto-falls-back, not silently leaving the app unlockable-by-nothing).

**Verification:**
```bash
flutter analyze
flutter test test/features/settings/ test/core/router/ test/core/auth/
```
Manual, **on the real device** (`T4X4F6UK4TA699S8`): set a PIN, force-close/reopen,
confirm both unlock paths work. Toggle biometric off with a PIN set — confirm PIN
unlock still works. Attempt to disable biometric with no PIN set — confirm the app
handles this safely (blocks it, or falls back correctly) rather than leaving the user
locked out or the app unlocked-by-nothing.

**Exit criteria:** Functional against live backend; the invariant above is explicitly
tested and confirmed, not just assumed; real-device verification of both toggle states
completed without regressing the existing biometric flow.

---

## Step 5b — Settings: Notifications screen ✅ DONE (2026-08-25)

**Re-verified against `piggybank-backend` (2026-08-25, follow-up session):** no client code
changed — the screen already talks to `PATCH /auth/me`, which `piggybank-backend` serves
identically. Full on-device manual smoke test still recommended (no Android device was
connected in the follow-up session either), but the API contract is confirmed live.

**Outcome:** Two preference toggles (`budget_alerts`, `weekly_summary` — key names taken
from the backend's own test fixtures, `test_notification_preferences_round_trip_via_patch_me`
in `backend/tests/test_auth.py`, rather than invented here) via
`lib/features/settings/data/notification_prefs_api.dart` (wraps `PATCH /auth/me`) and
`lib/features/settings/screens/notifications_screen.dart`. Added `User.notificationPreferences`
to `lib/core/auth/user.dart`, wired a Notifications row into the Settings list
(`lib/core/router/placeholder_screens.dart`), and updated that file's stale doc comment
that said this row was deliberately withheld. Missing/never-saved keys default to `true`
(opt-out model). Tests: `test/features/settings/data/notification_prefs_api_test.dart`,
`test/features/settings/screens/notifications_screen_test.dart` — all pass, plus the full
235-test suite as a regression check. `flutter analyze` clean (only pre-existing info-level
lints elsewhere). Manual verification against the live server: registered a throwaway test
user, PATCHed a non-default preference pair, re-logged-in, confirmed `GET /auth/me` still
returned it.

**Type:** Flutter. **Model:** default. **Depends on:** Step 4b.

**Context brief:** Straightforward client work against Step 4b's endpoints — no
lock-flow complexity here, unlike 5a.

**Task list:**
1. `lib/features/settings/data/notification_prefs_api.dart` — wraps Step 4b's
   endpoints.
2. `lib/features/settings/screens/notifications_screen.dart` — preference toggles per
   whatever set Step 4b settled on.
3. Add as a Settings row.
4. Tests: API wrapper test, widget test.

**Verification:**
```bash
flutter analyze
flutter test test/features/settings/
```
Manual: toggle a preference, confirm it persists against the live backend across a
logout/login cycle.

**Exit criteria:** Screen functional against live data, tests pass.

---

## Step 6 — AI infra: stand up Ollama, enable AI features

**Type:** Ops/infra. **Model:** default. Runs on the deployed server, not local dev.

**Context brief:** `insights` and `chatbot` backend routers are fully built (Q&A
endpoints, rate limiting, `Insight` persistence, Tavily web-search integration) but
conditionally mounted only when `AI_FEATURES_ENABLED=true`. **Check the live state on
the server directly rather than assuming** — `docker-compose.yml`'s own default for
this flag is `true`, but this session's Phase 7 deployment explicitly set it `false` in
the server's `.env.docker`; confirm the actual current value by reading that file on
the server, don't trust either the compose default or this note as gospel by the time
this step runs. **Model name**: the compose file's `OLLAMA_MODEL` default is
`finsight:latest` (a custom/fine-tuned prod model per `piggybank-backend/CLAUDE.md`'s
"Ollama (self-hosted, `llama3.1:8b` dev / `finsight:latest` prod)" note), not the
generic `llama3.1:8b`. For this home-server deployment, prefer pulling the plain
`llama3.1:8b` dev model unless a `finsight` Modelfile/build process is found elsewhere
in the repo (search for it — `grep -r finsight` — before assuming one needs to be built
from scratch) and set `OLLAMA_MODEL=llama3.1:8b` in `.env.docker` accordingly, since a
home box almost certainly doesn't warrant the "prod" model distinction.

**Task list:**
1. SSH to `100.121.165.7` (see Server access note above). Read the current
   `.env.docker` to confirm actual `AI_FEATURES_ENABLED`/`OLLAMA_BASE_URL`/
   `OLLAMA_MODEL` values — don't assume.
2. Check available resources (CPU/RAM, GPU presence) — an 8B model is usable CPU-only
   but slow; if resources are clearly insufficient, **stop here and report back rather
   than proceeding** — this step has an explicit abort branch, it does not have to
   succeed on the first attempt.
3. Add an `ollama` service to the deployed `docker-compose.yml`, **checking first**
   whether the sibling "stringmonitor" project already running on this same host has
   its own Ollama instance on port 11434 that could be reused instead of running a
   second one (per this session's deployment notes, that project does run its own
   Ollama) — reusing is preferable to duplicating if the model/resource situation
   allows it; if reusing, this task becomes "point `OLLAMA_BASE_URL` at the existing
   instance" instead of adding a new service.
4. Pull/confirm the model chosen above is available (`ollama pull llama3.1:8b` or
   equivalent).
5. Update `.env.docker`'s `OLLAMA_BASE_URL`/`OLLAMA_MODEL` to match what was actually
   set up (never leave it pointing at the stale jarvis default).
6. Verify `GET /api/insights/health` (Ollama reachability check, already implemented
   server-side) returns healthy.
7. Set `AI_FEATURES_ENABLED=true`, restart the backend container. **This interrupts
   the live app** — do this at a moment that doesn't collide with active testing, and
   note there is no automated rollback: if something breaks, the rollback is manually
   setting the flag back to `false` and restarting again, which is fast and safe (the
   flag change is the only irreversible-feeling part, and it's actually trivially
   reversible — say so explicitly to avoid over-caution here relative to the genuinely
   irreversible keystore step in 9a).
8. Manual smoke test: authenticated `curl` to `/api/insights/` or `/api/chatbot/chat`
   with a valid Pro-tier test account's token, confirm a real, coherent Ollama-
   generated response within a reasonable time.

**Verification:** Task 8's curl smoke test returning a real response is the exit
signal — no `flutter`/`pytest` gate for this ops-only step.

**Exit criteria:** `AI_FEATURES_ENABLED=true` on the deployed server, confirmed
Ollama reachable and responding to a real authenticated request with the correct
model, not just "the container started."

---

## Step 7 — Insights tab UI

**Type:** Flutter. **Model:** default. **Depends on:** Step 6.

**Context brief:** `Piggybank/docs/stitch-design-brief.md` §8: "propose a genuinely
considered layout for trend insights... use the hero metric card + progress card +
stat strip vocabulary already established elsewhere." Legacy `InsightsPage.tsx`
(`finance-app.v3-main/legacy/react-web/src/pages/InsightsPage.tsx`) is a reference to
consult, not port literally. Backend: `GET /api/insights/health`, `POST
/api/insights/`, list/get/delete, all Pro-tier gated (`require_pro_tier`) — handle the
non-Pro case via the existing `showPaywallPrompt` pattern
(`lib/shared/widgets/paywall_dialog.dart`, already used in `accounts_screen.dart`).

**Task list:**
1. `lib/features/insights/data/insights_api.dart` — mirrors `ConsentsApi`'s structure.
2. `lib/features/insights/models/` — request/response models.
3. `lib/features/insights/screens/insights_screen.dart` — replaces the current
   `PlaceholderScreen(title: 'Insights')` at `/insights` in `app_router.dart`.
   Question-input affordance + insight-history list, reusing existing hero-metric-
   card/progress-card/stat-strip components.
4. Paywall handling for non-Pro users.
5. Loading/error states following the `_AddAccountSheetState` convention.
6. Tests: API wrapper tests, widget tests for paywall-gated and normal states.

**Verification:**
```bash
flutter analyze
flutter test test/features/insights/
```
Manual, against the now-live AI backend: ask a real question, confirm a real answer
renders; test with a non-Pro account to confirm the paywall path.

**Exit criteria:** `/insights` route no longer a placeholder, returns real answers,
paywall path verified.

---

## Step 8 — Chatbot UI

**Type:** Flutter. **Model:** default. **Depends on:** Step 6 (benefits from Step 7
landing first for pattern reuse).

**Context brief:** No mockup/design-brief direction — design docs say "mention only."
Legacy `ChatPage.tsx` (133 lines) is the only reference. Backend confirmed:
`backend/app/chatbot/router.py`'s `POST /chat` is **synchronous, returns a complete
`ChatResponse` — it does not stream.** Build the UI to match this (a normal
loading-spinner-then-full-message pattern, not a token-by-token streaming UI) — this
was verified during blueprint review, not left as an open question for whoever
executes this step.

**Task list:**
1. Write a short design note (in `docs/` or extending `stitch-design-brief.md`)
   covering message-list layout and how this visually differs from Insights (a chat
   thread vs. a Q&A history list) enough to not feel like a duplicate feature.
2. `lib/features/chatbot/data/chatbot_api.dart`.
3. `lib/features/chatbot/screens/chatbot_screen.dart` — decide and document its nav
   entry point explicitly (not one of the 5 bottom-nav tabs; likely pushed from
   Insights or Settings) — don't leave this ambiguous.
4. Same paywall/loading/error conventions as Step 7.
5. Tests mirroring Step 7's pattern.

**Verification:**
```bash
flutter analyze
flutter test test/features/chatbot/
```
Manual: send a real message, confirm a coherent non-streamed response; verify the
chosen entry point is actually discoverable.

**Exit criteria:** Chatbot reachable and functional against the live backend, entry
point is a deliberate documented choice.

---

## Step 9a — Google Play: release signing

**Type:** Flutter/Android config. **Model:** strongest (Opus) — irreversible action.

**Context brief:** Currently debug-signed (`android/app/build.gradle.kts` has a
`// TODO` for release signing). No keystore exists. No `.gitignore` protection for one
exists either, independent of whether a keystore is generated in this session.

**Task list:**
1. **Before generating anything**, confirm with the user where the keystore file and
   its passwords will be backed up — this is genuinely unrecoverable if lost; losing it
   means the app can never be updated under the same Play Store listing again. Do not
   proceed past this confirmation.
2. Add `*.jks`, `*.keystore`, `key.properties` to `.gitignore` — do this regardless of
   whether keystore generation happens in the same pass; it's a real gap on its own and
   should not wait on the confirmation in task 1.
3. Generate the release keystore (`keytool -genkey`), store it outside the repo.
4. Wire `build.gradle.kts`'s release `signingConfig` to read from a git-ignored
   `key.properties` file (standard Flutter pattern), replacing the debug fallback.
5. Also verify (per the gap report's flagged-but-unaddressed item): confirm current
   `minSdk`/`targetSdk` (both currently inherited from Flutter's own Gradle plugin
   defaults, not hardcoded) against the current Play Store minimum `targetSdk` policy —
   this requires checking current external Play Store policy, not just reading the repo
   — and bump `targetSdk` explicitly in `build.gradle.kts` if the Flutter-default value
   is below Play's current floor.
6. Rebuild release APK/AAB, confirm it installs and runs identically to the
   debug-signed build tested on real hardware throughout this session.

**Verification:**
```bash
flutter build appbundle --release
```
Manual: install the release-signed AAB/APK on the real device, confirm core flows work
identically to the debug-signed build (login, consent, biometric/PIN unlock).

**Exit criteria:** Properly-signed release build exists and works on real hardware;
keystore is backed up per the confirmed plan and gitignored; `targetSdk` verified
against current Play policy.

---

## Step 9b — Google Play: launcher icons ✅ DONE (2026-08-24, on-device check pending)

**Outcome:** Source art cropped from the Stitch-generated `Piggybank app logo.jpeg`
comp (the mascot's rounded-square icon tile) into `assets/icon/app_icon.png`
(1024×1024) — user's explicit choice over recomposing the mascot render or
generating fresh art. `flutter_launcher_icons` added and configured in
`pubspec.yaml` (Android only — this project has no `ios/` platform folder, so
`ios: true` crashed on a missing Assets.xcassets path and was set to `false`);
adaptive icon background set to the sampled `#FEF9F3` cream from the source
comp, foreground reuses the same cropped art. `dart run flutter_launcher_icons`
ran clean, overwriting all `mipmap-*/ic_launcher.png` and adding
`drawable-*/ic_launcher_foreground.png` + `mipmap-anydpi-v26/ic_launcher.xml` +
`values/colors.xml`. Separate 512×512 Play Store listing icon saved to
`assets/icon/play_store_icon_512.png`. **Not yet done:** no device was connected
via `adb` this session — the "uninstall/reinstall, confirm icon renders
correctly" verification from the task list below is still outstanding, do it
next time a device is attached.

**Type:** Flutter/Android assets. **Model:** default.

**Context brief:** No `flutter_launcher_icons` config exists, no custom icon source
asset found anywhere in the repo (`assets/` holds only the 9 original UI mockup
JPEGs) — current icons are very likely still Flutter's unmodified default template
icon.

**Task list:**
1. Source real icon art — check `DESIGN.md`'s described mascot/wordmark for any
   existing usable source file first before commissioning something new.
2. Add and configure `flutter_launcher_icons` to generate the full Android icon set.
3. Generate the separate 512×512 high-resolution icon Play Store's own listing
   requires (distinct from in-app launcher icons).

**Verification:** `flutter pub run flutter_launcher_icons` completes without error;
manually confirm the new icon appears correctly after a fresh install on the real
device (old icon caches can be misleading — uninstall/reinstall to verify, don't just
rebuild over the existing install).

**Exit criteria:** Real, non-default icons at all required sizes including the
512×512 store asset.

---

## Step 9c — Google Play: public privacy-policy URL

**Type:** Infra, but **deliberately not touching `piggybank-backend`'s backend
server**. **Model:** default.

**Context brief:** The deployed backend host (`100.121.165.7`) is Tailscale-only —
routing a public URL through it would mean either exposing that host to the public
internet (a real security posture change, out of scope for a solo dev's home box) or
setting up a separate public ingress, both bigger changes than this single static page
warrants. **Use a separate, free, purpose-built static host instead** (GitHub Pages or
Cloudflare Pages are both zero-cost and don't touch the Tailscale-only infrastructure
at all) — this correctly satisfies Play Store's "publicly reachable URL" requirement
without any exposure-model change to the existing deployment.

**Task list:**
1. Create a minimal static site (a single HTML page is sufficient) containing the
   privacy policy text ported from `finance-app.v3-main/legacy/react-web/src/pages/
   PrivacyPolicyPage.tsx` — this is already real, reviewed copy (the same source used
   for this session's in-app consent screen), don't write new text.
2. Publish it via GitHub Pages (simplest if a public or appropriately-scoped repo
   already exists for this) or Cloudflare Pages.
3. Confirm the resulting URL is actually publicly reachable (test from outside any
   Tailscale/VPN context) before treating this as done.

**Verification:** `curl` the published URL from a network with no Tailscale
connection, confirm the page loads.

**Exit criteria:** A real, public, Tailscale-independent privacy-policy URL exists and
is verified reachable from outside the private network.

---

## Step 9d — Google Play: store listing assets

**Type:** Content/assets. **Model:** default. **Depends on:** Steps 1–8 (needs a
feature-complete app to screenshot meaningfully).

**Context brief:** No screenshots, feature graphic, or listing description exist
anywhere in the repo today.

**Task list:**
1. Capture store-quality screenshots from the real device, covering the now-complete
   feature set (including the screens built in Steps 1–8).
2. Produce a feature graphic per Play Store's format requirements.
3. Write listing description copy.
4. Note explicitly (not code work, just a checklist item for whoever submits): content
   rating questionnaire and the Data safety section are Play Console UI steps with no
   code artifact — the actual Play Console submission remains a manual step outside
   this blueprint's scope entirely.

**Verification:** N/A — content review only (does it look right, is the copy accurate).

**Exit criteria:** All listing assets ready for upload; the manual Play Console
submission checklist is the one remaining action, explicitly outside this plan.

---

## Notes for whoever executes this plan

- Every implementation step should end with `flutter analyze`/`ruff check .` clean and
  its new tests passing — test coverage is a per-step requirement for new work, not a
  retrofit project for the existing untested domains listed in the gap report.
- Use `/save-session` at the end of each step and `/resume-session` to pick the plan
  back up — this spans many sessions.
- Steps 5a and 6 both touch or interact with the exact lock-screen/biometric code
  hardened earlier this session (`FlutterFragmentActivity`/`USE_BIOMETRIC` fix) — treat
  any regression there as high-severity, not routine churn.
- Step 0's Admin gate is absolute — see its exit criteria. No loophole for "small"
  Admin work exists in this plan; an earlier draft had one and it was removed on
  review specifically because it contradicted the header's own stated rule.
