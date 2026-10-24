# Piggybank: status

**As of 2026-10-13 (evening SAST); partly updated 2026-10-19 (PR merges, monetisation decisions) and 2026-10-24 (deploy check, distribution decision, founder review update).** This page is the one place that says where Piggybank stands. Session files and memories point here.

**Verified** means checked today against GitHub, the live host, or the repo. **UNVERIFIED** means it was carried over from notes.

---

## 1. Shipped state

| What | State | How verified |
|---|---|---|
| App on `master` | **1.0.10+11**, `1e9f57c` (#84). Since 1.0.9+10: #79 (notification capture no longer fails silently), #80 (version bump), #81 to #84 (docs, test, workspace cleanup). **UNVERIFIED:** whether a 1.0.10+11 APK has been published | `git log origin/master`, `pubspec.yaml` (2026-10-24) |
| Published APK | `downloads/piggybank-latest.apk`, 61,956,520 bytes, last-modified 13 Oct 11:14 UTC | `curl -I http://100.121.165.7/downloads/...` |
| Backend on `main` | `d35db82` (#35). Since #30: #31, #32, #33 (Penny error messages, Funnel deploy fix), #34, #35 | `git log origin/main` (2026-10-24) |
| Backend running on host | **`f3112be`** (the #33 branch tip), which contains #31 and #32; its `backend/` tree is identical to `main`. Backend healthy, Caddy and Postgres up 3 days, still bound on **both** `100.121.165.7:8000` and `127.0.0.1:8000`. `/api/health` → `{"status":"ok","ai_features_enabled":true}` | `sudo -n /usr/local/sbin/piggybank-status` on fynbos-server (2026-10-24); `git merge-base --is-ancestor`, `git diff` |
| Database migrations | alembic `99f23b1bebc5 (head)` on 2026-10-13. **UNVERIFIED since:** #32's migration `7c1e9a4b2d63` runs on container start, so the host should now read it, but `alembic current` was not re-run (the status command doesn't show it) | `docker exec … alembic current` |
| Public HTTPS (Tailscale Funnel) | `https://tiaanbossies-h81m-ds2.tail886b94.ts.net/api/health` → 200 | curl |
| Tailnet health | `http://100.121.165.7:8000/api/health` → `{"status":"ok","ai_features_enabled":true}` | curl |
| Open PRs | None in the app. Backend **#32** and app **#78** (loans anchor) were **merged 2026-10-13 ~17:35 UTC**. **#32 is deployed** (host code checked 2026-10-24) | `gh pr view` |
| Who gets Pro | **Every new account is created as Pro, with no end date** (deliberate promo in `subscriptions/deps.py`). `plans/founder-review-fixes.md` PR 1 adds the end date (`PRO_PROMO_UNTIL`, 28 Feb 2027); not started | `deps.py` on `main` (2026-10-24) |
| Off-host backups | **Not installed.** No backup cron or timer on the host, and `BACKUP_*` is unset in `.env.docker`. `make restore-check` has never run | ssh: cron.d, `systemctl list-timers`, env keys |
| Server keys (names only) | `TAVILY_API_KEY` **unset**; `OLLAMA_BASE_URL` **set**; `SMTP_HOST` **unset**; `BACKEND_BIND=100.121.165.7`; `COMPOSE_FILE` unset | ssh, grep of key names (no values read) |

**What those keys mean:**
- **Tavily unset:** Penny's policy research returns "unavailable", but no data leaves the server.
- **Ollama set:** receipt OCR stays local, so Anthropic never receives receipt images.
- **SMTP unset:** no email goes out.
- **COMPOSE_FILE unset:** every deploy still needs the two-file compose command (see §5).

### Where the notes and memories disagree with what's live
- `plans/device-pass-2-checklist.md` §0 says the host was "still at #18 (alembic a4528c75979a)". That is **out of date**: the host is at head `99f23b1bebc5`, so step 0's first box can be ticked. The checklist is also **untracked** in the app repo.
- The session file `2026-10-13-piggybank-prebeta` lists app PR #69 as a DRAFT awaiting a device test. It was **merged** on 2026-10-13 and shipped in 1.0.9+10. It still has not been tested on a phone over mobile data.
- The memory `project_piggybank_sprint_goal` still reads "beta paused behind cost-cutting" and lists cost-cutting PRs as open. All 8 are **merged and shipped** (1.0.7+8). What's left is acceptance (§2), not code.

---

## 2. Goals, in priority order (confirmed by Tiaan on 2026-10-13: cost-cutting stays first)

| # | Goal | Status | What "done" still needs |
|---|---|---|---|
| 1 | **Cost-cutting / "afford the rent"** (`plans/cost-cutting-plan.md`) | **Code shipped, acceptance open.** All 8 PRs are merged (backend #12–#15, app #30–#33) and live since 1.0.7 | **None of the 6 acceptance boxes is ticked.** Tiaan needs to: set the rent target; back-fill 3–6 months via CSV so detection has history; confirm the recurring list; enter his policies. Penny's sourced answer can't pass while `TAVILY_API_KEY` is unset (D1 says "keep Tavily"). |
| 2 | **Daily driver** (sprint from 2026-09-22) | **In progress, not measured.** Auto-capture, one-tap review and the UX and visual reworks are all shipped | The 14-day streak has not been reported as started. The filter-report `would_drop_real` check has not been done. The three metrics (14 days, ≥80% auto-captured, under 1 min/day) are unmeasured. |
| 3 | **Friends & family beta, wave 1** (~2026-11-23; `plans/next-goal-friends-family-beta.md`) | **Paused behind #1; infrastructure half ready.** Now a **Play closed test with 12 testers** (decided 2026-10-24), not 3–5 sideloaded installs: 12 for 14 days clears Play's production gate and gives a pricing signal | Public HTTPS is live. Backups, the Play account, an Information Officer, the device pass on mobile data, and the Pro promo end date (founder-review-fixes PR 1) are all open (§3). |

The **visual rework epic** (#50–#65) and **QA pass 1** (#66–#76, backend #23/#27/#29/#30) are **closed**. Only device pass 2 remains for them.

---

## 3. Open threads

| # | Item | Owner | Blocker | Source |
|---|---|---|---|---|
| 1 | **Device pass 2** on 1.0.9+10, on mobile data: install, HTTPS, Penny's real chat error, Home bell inbox, fingerprint login after logout, categories, pay-cycle labels | **Tiaan** (Claude can't sign in) | None | `plans/device-pass-2-checklist.md` |
| 2 | **Cost-cutting acceptance**: target, CSV back-fill, recurring list, policies | **Tiaan** (his own data) | None | `plans/cost-cutting-plan.md` §Acceptance |
| 3 | **Tavily key** for Penny's policy research (D1) | **Tiaan** (account + host env) | Decision: keep Tavily or drop that criterion | cost-cutting D1; host env |
| 4 | **Liability from-pattern bug**: `POST /liabilities/from-pattern` sets `outstanding_amount = monthly_amount`, which lowers net worth by one month's cost (still at `liabilities/router.py:94` on `main`) | **Fixed: backend #31 merged 2026-10-13**, CI green on `main`. **Tiaan** deploys | Deploy (no migration) | cost-cutting §Side findings |
| 5 | **Loans source of truth**: balances froze and back-logged payments double-counted | **Decided (all recommended, D1c–D4i) and built:** backend **#32** (anchor + nightly roll-forward, migration `7c1e9a4b2d63`) and app **#78** ("Log extra payment", statement date, review banner). **Both merged 2026-10-13. Backend #32 deployed** (checked 2026-10-24); #31 too. App #78 is in 1.0.10+11 on `master` | Publish the 1.0.10+11 APK if not done | `plans/loans-source-of-truth.md` |
| 6 | **Backups**: install the cron, the `age` key and the off-host target, then run `make restore-check` | **Tiaan** (host root/accounts) | None; **blocks beta invites** | backend #19, runbook |
| 7 | **BACKEND_BIND flip** to `127.0.0.1` and drop the funnel override | **Tiaan** on the host | Several days of 1.0.9 on mobile data first (#1); flipping early cuts off 1.0.8 installs | prebeta memory |
| 8 | **SMTP_\*** in `.env.docker` | **Tiaan** | Pick a provider | qa_pass1 memory |
| 9 | **RA unit-trust questions** (#74 §5), including the RA limit bug (R36k vs 27.5% capped at R350k/R430k) | **Tiaan** answers; **Claude** builds | 3 questions | app #74 |
| 10 | **Play developer account** (US$25 once, about R450; government ID and a card in your name; new personal accounts need **12 testers opted in for 14 days** before production) | **Tiaan** | Money/identity. **Now on the critical path:** wave 1 runs as a Play closed test (item 17) | `reviews/2026-10-24-founder-pricing-full.md` §7 |
| 11 | **Information Officer** registration (POPIA) | **Tiaan** | None | pre-beta research, backend #22 |
| 12 | **Operator register Tavily row**: mark it "not configured, no data sent" (verified today) | **Claude** (docs PR) | Tiaan's go | prebeta session |
| 13 | **Optional `COMPOSE_FILE`** in the host `.env.docker`, so a plain `docker compose up` keeps the Funnel override | **Tiaan** (host) | Offered, not answered | qa_pass1 memory |
| 14 | **Local repo housekeeping**: see below | **Claude**, on Tiaan's yes | None | git |
| 15 | **Ollama 5-concurrent-chat latency test; Android 15 notification-capture test** | **Tiaan** (device) / **Claude** (load script) | None | pre-beta research |
| 16 | **Filter-report check** (`/api/detection/filter-report`, `would_drop_real`) | **Claude** can read it if Tiaan shares a token, or **Tiaan** | Auth | sprint-goal memory |
| 17 | **Monetisation and distribution.** Decided 2026-10-19: Piggybank is meant to earn money; not VAT-registered; R29/mo founding price approved (12 months, beta testers + first 50 payers). **Decided 2026-10-24 (Tiaan), replacing "sideload only":** beta wave 1 runs as a **Google Play closed test**, and the paid launch uses **Google Play Billing** (15% fee in SA, ZAR payouts). In-app PayFast goes, as `plans/founder-review-fixes.md` PR 1 already plans; a gateway (PayFast or Paystack) is kept only for a possible future web sign-up, so a live PayFast merchant account is **no longer needed** for the paid launch. Play's user choice billing was rejected: it costs more at R49. Paid Pro stays **off** until the beta proves it | **Tiaan**: Play developer account (item 10). **Claude**: founder-review-fixes PR 1 | Play account | `reviews/2026-10-24-founder-pricing-full.md` §7, §11 |
| 18 | **Founder review update (2026-10-24) findings to act on:** (a) banks already stop/reverse debit orders in-app, so Pro sells *finding* recurring costs across banks; (b) plan on ~2% paid conversion, not 5%; (c) debit-order dispute window is now 60 days (PASA, 13 Apr 2026); (d) proposed beta additions: "where to stop it" link per bank and a new-debit-order alert with 60-day countdown; (e) Vault22 (ex-22seven) is the main competitor to watch; (f) the app requests no SMS permission, so Play's SMS policy doesn't apply, but expect a review question on notification-listener use; (g) Android developer verification goes global in 2027 | **Tiaan** decides (d); **Claude** plans and builds it on a yes | Tiaan's yes on (d) | `reviews/2026-10-24-founder-pricing-full.md` §1, §5, §6.3, §7 |

**Local repo housekeeping (item 14):**
- The app checkout is on the unpushed `fix/publish-download-url` (`9d9d429`), which is mostly redundant after backend #30.
- The local `master` is stale.
- Worktrees `pb-app-land` and `pb-backend-land` were archived on 2026-10-24 (`../_archive/`); the branch is parked, see `docs/BRANCHES.md`. `F:/piggybank-clock` is still a leftover.
- The backend checkout is on `fix/downloads-redirect` (`d0f15cd`, already merged as #30).
- About 30 stale local feature branches remain.
- `plans/device-pass-2-checklist.md` is now tracked.

---

## 4. Next actions (ranked: cost-cutting first, then what unblocks the beta)

1. **Tiaan: device pass 2** (item 1). It's cheap, and it proves the build you depend on for everything below works off the tailnet. It also starts the clock for the BACKEND_BIND flip.
2. **Tiaan: use the Savings plan for real** (item 2). Back-fill CSVs, set the rent target, then confirm and cut the recurring list. This *is* the top goal; no more code is needed to start.
3. **Claude: correctness fixes behind the savings numbers** (items 4 and 5). Fix the from-pattern net-worth bug, and write up loans source-of-truth options for a decision. Wrong numbers would undermine goal #1.
4. **Tiaan: Tavily decision and key** (item 3). It's the only blocker to finishing cost-cutting acceptance.
5. **Tiaan: backups plus restore-check** (item 6). It protects real financial data now and is the hard gate before any beta invite.

**Recommended next session:** run *"Piggybank device pass 2 triage"* once Tiaan sends results from the checklist. If he hasn't run it yet, use *"Savings correctness"* instead: one backend PR for item 4, plus a decision memo for item 5.

---

## 5. Gotchas worth keeping

- **Backend deploy (until BACKEND_BIND flips):**
  `git pull && docker compose --env-file .env.docker -f docker-compose.yml -f docker-compose.funnel.yml up -d --build`
  The plain command drops the loopback mapping, which makes Funnel return 502. Migrations run automatically on container start. Confirm afterwards with `alembic current`.
- **Funnel only routes `/` to the backend.** `/downloads/*` is answered by a 307 to `http://100.121.165.7/downloads` (backend #30), so APKs stay tailnet-only.
- **Host access:** `ssh mcp@100.121.165.7`, read-only checks only. The auto-mode classifier blocks remote writes, so Tiaan deploys.
- **Release build out of memory:** the C: drive is near-full. Temporarily set `org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m` and `kotlin.compiler.execution.strategy=in-process` in `android/gradle.properties`, build, then restore it. Kill stray Kotlin daemons first.
- **Flutter tests:** set `TMP`/`TEMP` to `F:\Templutter`.
- **Backend tests:** need `AI_FEATURES_ENABLED=true`; venv at `backend/.venv/Scripts/python`.
- **Line endings:** the system git has `core.autocrlf=true` but blobs are LF. Use `git -c core.autocrlf=false` per command, never run `git config` inside a worktree, and give native git `C:/…` paths (not `/c/…`).
- **Goldens:** the clock is pinned to 2026-10-15 10:00 (`withClock`/`testShot`; the app reads `clock.now()`). The harness is `test/goldens/screenshot_harness.dart`. Fonts are Plus Jakarta Sans and Nunito Sans.
- **Never run `dart format` on `lib/`.** The repo isn't format-clean, and it once rewrote 136 files.
- **Stacked PRs:** squash-merging the base strands the PRs above it (this happened in QA pass 1 and earlier). Land through one combined PR, or retarget each PR to the trunk before merging.
- **Editing `pubspec.yaml`:** use sed, not PowerShell `Set-Content`. Set-Content adds a byte-order mark (BOM) and mangles em-dashes.
- **Undo SnackBars** need `persist: false` on Flutter 3.29+.
- **`formatZAR`** uses U+00A0 (no-break) spaces, so test literals must too.
- **Firecrawl:** run searches one at a time (parallel calls get a 429).
- **Stitch:** generate calls time out client-side but finish server-side, so poll with `get_project`. Say "MOBILE ONLY, 390px". Use only the 4 Penny cutouts in `assets/penny/`.
- **Release symbols** for every version are in `02_Clients/Piggybank App/ops/symbols/`.
