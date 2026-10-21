# Founder review fixes: bugs, services, UI, code review

> **Written 2026-10-21** from the founder review of 20 Oct 2026. Status: planned, not started.

## Context
The founder review (20 Oct 2026) found 3 P0 bugs, some P1/P2 items, gaps in the services, UI polish to do, and code-review debt. This plan fixes all of it before outside testers arrive.

**Decisions made:**
- **Play Billing** (Jan) is the payment path. In-app PayFast is removed now.
- Pro stays a free beta grant until **28 Feb 2027**, set by `PRO_PROMO_UNTIL`.
- **4 PRs, by phase.** The Haiku fallback is out of scope for now.

**Repos:**
- `piggybank` (Flutter): default branch `master`.
- `piggybank-backend` (FastAPI): default branch `main`. PR #33 (Funnel/Penny) is open on `claude/affectionate-darwin-cv3gxf`.

**One designated branch per repo**, so the PRs go one after another. After each merge the branch restarts from the default branch, and then the next PR opens.

Exploration corrected four of the review's items:
- `deploy.yml` is already gated on `vars.DEPLOY_ENABLED`.
- Only one route mixes async with the sync DB session (`payfast_notify`).
- There are no per-bank parsers: extraction is a single Ollama prompt.
- The net-worth rounding difference is the spec's own rule: the hero shows no cents, rows show cents. No change is needed.

---

## PR 1: P0 bugs (both repos)

### Backend
**P0-1 and P1-5: remove in-app PayFast.**
- Delete `subscriptions/payfast.py`.
- Delete the routes `POST /checkout`, `GET /checkout/{id}` and `POST /payfast/notify` (`subscriptions/router.py:52-174`).
- Delete the `PAYFAST_*` settings (`config.py:102-115`) and their compose and env-example lines, plus `scripts/flip_existing_users_to_pro.py`.
- Keep the `PaymentTransaction` table and the `payfast_token` column. That avoids a destructive migration.
- Replace `conftest.py`'s `_upgrade_to_pro` (which uses a real ITN) with a direct DB write, like `_downgrade_to_free`.
- Add a "removed in <sha>" note to `docs/payment-gateway-scope.md`. It should list the hardening a future web sign-up must do:
  - `hmac.compare_digest` for signatures
  - an `amount_gross` check
  - ITN idempotency
  - a sync `def`
  - `html.escape` in the checkout HTML
  - a checkout token with its own JWT `type` (a `purpose` claim alone is still a valid Bearer token, `auth/dependencies.py:45`)
  - the PayFast cancel API

**P0-2 and P1-4: make Pro expire.**
- **Migration** (after `7c1e9a4b2d63`): add `subscriptions.source`, `String(16)` nullable, with values `promo` / `play` / `manual`. Backfill existing PRO rows to `promo`.
- **Config:** `pro_promo_until: datetime | None` (`.env.docker.example`: `PRO_PROMO_UNTIL=2027-02-28T23:59:59+02:00`).
- **`subscriptions/deps.py`:**
  - `get_or_create_subscription` creates `PRO, source=promo, current_period_end=pro_promo_until`. Once that date has passed, it creates FREE.
  - New `has_pro(sub, now=None)`: tier is PRO and `current_period_end` is None or in the future. `require_pro_tier` uses it, so expiry holds between job runs.
  - Swap the raw `tier == PRO` checks for `has_pro`: accounts (`router.py:349`), portfolios (`:599`) and `salary/detection.py:120`. Grep for any others.
- **New `subscriptions/expiry.py`** with `expire_subscriptions(now=None)`. It stamps promo rows that have no end with the setting, and drops lapsed PRO rows to FREE.
  - Follows the pattern of `liabilities/balance.py:147`.
  - Registered at 00:05 UTC in `scheduler.py`, with a matching startup log line.
- `/cancel` stays as it is. Nothing bills now, so the CPA exposure is gone.
- `SubscriptionOut` gains `source`.

**Detection queue-acknowledgement bug (found during exploration).**
- **The bug:** the app acks `processed` items from the head of the queue, but `processed` counts allowlisted items only (`financial_event_extractor.py:344`). Rejected items are re-uploaded forever and inflate the filter report.
- **Fix:** `POST /detection/ingest/notifications` also returns `accepted = len(items)`.

**Tests:** expiry (promo end, lapsed period, job stamp and drop, new sign-up after the promo gives Free), `has_pro` at the limits, removed routes return 404, `accepted` count.

### App
- **Subscription screen** (`lib/features/settings/screens/subscription_screen.dart`):
  - Remove Upgrade, "Waiting for PayFast" and Cancel.
  - Show "Pro · free during the beta, until 28 Feb 2027" (`fullDate`), or "Paid Pro is coming soon" when on Free.
  - Remove `startCheckout`/`cancel` from `subscription_api.dart` and parse `source`.
  - Update both test files.
- **P0-3: SMS filter**, in `android/.../DetectionNotificationListenerService.kt`:
  - Move `verdict()` (:73-80) into a pure `object DetectionFilter`.
  - Add a `MESSAGING_PACKAGES` set: Google Messages, Samsung Messages, `com.android.mms`, WhatsApp, Telegram, Signal, Messenger.
  - **Drop before `enqueue`:**
    - a messaging app with no sender allowlist (new verdict `messaging_no_senders`, kept on the device only)
    - any package with a sender allowlist where the sender isn't on it
  - `no_amount_shape` stays shadow-only until the filter-report gate (`would_drop_real == 0`).
  - In detection settings, ticking a messaging app opens `_SenderAllowlistDialog` (:541) straight away, with the line "Only messages from senders you tick are read."
  - Add JUnit to `android/app/build.gradle.kts`, plus `DetectionFilterTest.kt` covering every branch and `AMOUNT_SHAPE`.
- **Ack fix:** `notification_capture_service.dart:43` acks `accepted ?? processed`. Fix the stale doc comment in `detection_api.dart:55` and add tests.

---

## PR 2: P1/P2 fixes and UI polish (mostly the app)

- **P1-6, FAB covers content.** The `AppSpace.fabInset` token already exists (`app_tokens.dart:243`, 88).
  - Raise it to clear the extended FAB (56) plus 16 dp plus the nav-bar overlap, measured on the goldens.
  - Use it everywhere. Replace the private `_kFabClearance = 88` in accounts, assets, liabilities, liability_detail, tfsa/ra ledgers and portfolio_detail, and the `96` in manage_categories.
  - Normalise Home (`dashboard_screen.dart:84`), Transactions (`:171,:203`) and the Plan segments (`s16 + fabInset`).
- **Dates.** Replace `goals_screen.dart:152`'s `_formatDate` and the other display-only ISO dates with `fullDate()` (`lib/core/format/dates.dart:24`):
  - account/liability detail, liabilities, tfsa/ra ledgers
  - transaction sheet and screen, imports
  - holding sheets, instrument comparison, subscription screen
  - Leave `*_api.dart` alone.
- **Net worth hub, Accounts row** (`net_worth_screen.dart:95`). Parse `account_cash_total` and `assets_total`, which the backend already sends (`summaries/router.py:79-100`), in `summaries.dart`. Accounts shows the cash total. Assets switches to `assetsTotal`, because `totalAssets` already includes the cash.
- **Home savings line** (`dashboard_screen.dart:192`): "R 1 240 to go · 75% of R 5 000".
- **Penny tab icon** (`app_shell.dart:115`): replace `smart_toy` with `PennyImage('assets/penny/welcoming.png', size: 24)`. Selected uses full opacity, unselected 0.6. Home's `Icon` stays first so the pill measurement (`:171`) still works.
- **Plan month switcher:** move `BudgetMonthSwitcher` out of the `TabAppBar.bottom` (`plan_screen.dart:64`) and into the top of the Budgets body, below the segments.
- **Login copy** (`login_screen.dart:199`): "Encrypted in transit. Your data stays in South Africa."
- **Onboarding, 7 pages to 3** (`onboarding_screen.dart:33-68`): welcome, how it works, all set. `NotificationAccessBanner` (`review_banner.dart:56`) also shows at the top of Transactions (`transactions_screen.dart:97`) and in its empty state.
- **P2 hygiene:**
  - Real descriptions in `README.md` and `pubspec.yaml:2`.
  - Change the backend `deploy.yml:58` path `/opt/piggybank-backend` to `~/piggybank-backend`.
  - The cleartext fallback in `api_config.dart` stays until the Funnel has run a clean week; it is removed in a later release.
- **Tests and goldens:** update the tests the exploration listed:
  - `dashboard_screen_test` :105/:667/:874/:904
  - `goal_sheet_test` :105/:122
  - `onboarding_screen_test` :87
  - `budgets_screen_test` :125
  - `plan_look_test`
  - Regenerate `test/goldens/` (tab_roots and audit), with before/after crops in the PR.

---

## PR 3: Services (both repos)

1. **Backups.**
   - `scripts/backup.sh` and `restore-check.sh` take their default `COMPOSE_DIR` from the script's own repo root; today it is hard-coded to `/opt/...` (the runbook says `~/piggybank-backend`).
   - The off-host step also sends an age-encrypted copy of `.env.docker`.
   - Update the runbook.
2. **Crash reporting (Sentry, free tier, EU region).** It does nothing unless a DSN is set.
   - **Backend:** `sentry-sdk[fastapi]` in `requirements.in`, then recompile. Set `send_default_pii=False` and strip request bodies and headers in `before_send`.
   - **App:** `sentry_flutter`, initialised in `main.dart` only when `--dart-define=SENTRY_DSN` is set. No bodies and no user email. Upload the `--split-debug-info` symbols from `scripts/build_release.sh`.
   - Update `docs/popia-operators.md:33` and the privacy-policy line.
3. **Report a problem.**
   - **Backend:** new `feedback/` module.
     - `Feedback` model (user_id, message ≤2000, app_version, screen, created_at), with a migration.
     - `POST /api/feedback`: signed in, 5 per hour.
   - **App:** Settings → "Report a problem" sheet. It attaches the app version from `package_info_plus` (already a dependency) and the current route.
4. **Uptime.**
   - `GET /api/health/ready` runs a DB `SELECT 1`. `/api/health` stays as it is for the Docker healthcheck.
   - Tiaan creates an UptimeRobot monitor on the Funnel `/api/health/ready`.
5. **Real client IPs behind Funnel.**
   - `entrypoint.sh` reads `FORWARDED_ALLOW_IPS`, with the default unchanged (`172.16.0.0/12`).
   - **On the server:** `docker network inspect` the compose network, and check the access log shows the phone's mobile IP, not 172.x. If every Funnel user shared one IP, login would be limited to 5/min for everyone combined.
6. **Detection fixtures.**
   - Add `backend/tests/fixtures/notifications/<bank>.jsonl` with redacted real samples and the expected amount, merchant and direction.
   - A non-live test runs `validate_and_clean_event`. A `@pytest.mark.live` test runs the extractor against Ollama.
   - Start with Tiaan's own bank, then add Capitec, FNB, Standard Bank, Absa, Nedbank, Discovery, TymeBank and Investec as testers send samples.
7. **Penny load test.**
   - `scripts/penny_load_test.py` runs 5 concurrent `/api/chatbot/chat` calls and prints p50/p95.
   - Tiaan runs it on the server, and the result goes in the runbook.
   - Decide on Haiku only if p95 is too slow.

---

## PR 4: Code-review cleanup

- **Split the two large screens.**
  - `savings_plan_screen.dart` (1,057 lines) and `policy_screen.dart` (900) move their private widgets into `lib/features/savings/widgets/`.
  - These are pure moves, so the goldens must stay byte-identical.
- **Async/sync guard.** The only offender is removed in PR 1. Add a backend test that walks `app.routes` and fails if a coroutine endpoint depends on `get_db`.
- **`models.py` stays one file.** Splitting it is churn for alembic and 56 migrations, and fixes no bug.
- **App doc sprawl.**
  - Move `IMPLEMENTATION_PLAN.md`, `REFACTORING_COMPLETE.md`, `SESSION_TIER1_COMPLETE.md`, `TIER2_KICKOFF.md` and `QA_FINDINGS.md` into `docs/archive/`.
  - Move the finished plans into `plans/archive/`: the cost-cutting, ux-improvement, ux/visual-rework, nav-stitch-ota, penny-onboarding-tour, production-audit ×2, qa-list, fix-it, full-suite-qa ×2, launch-readiness, production-completion and stitch-* plans.
  - `DESIGN.md`, `next-goal-friends-family-beta.md` and `research-2026-10-pre-beta-infra.md` stay where they are, and get a `plans/README.md` index.
- **App `CLAUDE.md`.** The repo doesn't track one. Write one from the blueprint conventions (analyze/test gate, goldens, never `git add -A`, no `dart format` on `lib/`, commit style). First check that Tiaan has no untracked local copy, because a `git pull` would then clash with it.

---

## Server and admin tasks for Tiaan
- Merge PR #33 and run its deploy steps.
- Add `PRO_PROMO_UNTIL` to `.env.docker` after PR 1.
- Install the backup cron, run `make restore-check` and note the date in the runbook.
- Create Sentry and UptimeRobot accounts, then put the DSNs in `.env.docker` and in the release build defines.
- Register the Information Officer, and open the Play Console account.

## Verification
- **Backend, every PR:** `cd backend && ruff check . && pytest` must be all green, with the count only going up.
- **App:** there is no Flutter SDK in this session. Try installing the Flutter stable SDK. If the network blocks it, Tiaan runs these locally before each merge:
  - `flutter analyze`
  - `flutter test`
  - `flutter test --update-goldens test/goldens/`, then a clean re-run
  - `cd android && ./gradlew :app:testDebugUnitTest` (this needs the Flutter SDK too)
- **End to end after PR 1 is deployed:**
  - A new account shows "Pro until 28 Feb 2027".
  - Setting a test account's `current_period_end` in the past gives 402 on Penny and Free limits on the next request.
  - A Google Messages SMS from an unticked sender never shows up in `GET /api/detection/filter-report` observations.
  - Rejected items leave the device queue.
- **After PR 2:** check on the phone that FABs no longer cover the last row on Home, Budgets, Goals or Savings, and that the Accounts row shows the cash total.
