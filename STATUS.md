# Piggybank: status

**As of 2026-10-13 (evening SAST); partly updated 2026-10-19 (PR merges, monetisation decisions).** This page is the one place that says where Piggybank stands. Session files and memories point here.

**Verified** means checked today against GitHub, the live host, or the repo. **UNVERIFIED** means it was carried over from notes.

---

## 1. Shipped state

| What | State | How verified |
|---|---|---|
| App on `master` | **1.0.9+10**, `a342543` (#76) | `git show origin/master:pubspec.yaml` |
| Published APK | `downloads/piggybank-latest.apk`, 61,956,520 bytes, last-modified 13 Oct 11:14 UTC | `curl -I http://100.121.165.7/downloads/...` |
| Backend on `main` | `782fc53` (#30) | `git log origin/main` |
| Backend running on host | `782fc53`, container healthy, bound on **both** `100.121.165.7:8000` and `127.0.0.1:8000` | ssh `mcp@100.121.165.7`: `git log -1`, `docker ps` |
| Database migrations | alembic `99f23b1bebc5 (head)` | `docker exec … alembic current` |
| Public HTTPS (Tailscale Funnel) | `https://tiaanbossies-h81m-ds2.tail886b94.ts.net/api/health` → 200 | curl |
| Tailnet health | `http://100.121.165.7:8000/api/health` → `{"status":"ok","ai_features_enabled":true}` | curl |
| Open PRs | None. Backend **#32** and app **#78** (loans anchor) were **merged 2026-10-13 ~17:35 UTC** (checked 2026-10-19). **UNVERIFIED:** whether #32 is deployed (host alembic should read `7c1e9a4b2d63`) | `gh pr view` |
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
| 3 | **Friends & family beta, wave 1** (~2026-11-23, 3–5 Android testers; `plans/next-goal-friends-family-beta.md`) | **Paused behind #1; infrastructure half ready** | Public HTTPS is live. Backups, the Play account, an Information Officer, and the device pass on mobile data are all open (§3). |

The **visual rework epic** (#50–#65) and **QA pass 1** (#66–#76, backend #23/#27/#29/#30) are **closed**. Only device pass 2 remains for them.

---

## 3. Open threads

| # | Item | Owner | Blocker | Source |
|---|---|---|---|---|
| 1 | **Device pass 2** on 1.0.9+10, on mobile data: install, HTTPS, Penny's real chat error, Home bell inbox, fingerprint login after logout, categories, pay-cycle labels | **Tiaan** (Claude can't sign in) | None | `plans/device-pass-2-checklist.md` |
| 2 | **Cost-cutting acceptance**: target, CSV back-fill, recurring list, policies | **Tiaan** (his own data) | None | `plans/cost-cutting-plan.md` §Acceptance |
| 3 | **Tavily key** for Penny's policy research (D1) | **Tiaan** (account + host env) | Decision: keep Tavily or drop that criterion | cost-cutting D1; host env |
| 4 | **Liability from-pattern bug**: `POST /liabilities/from-pattern` sets `outstanding_amount = monthly_amount`, which lowers net worth by one month's cost (still at `liabilities/router.py:94` on `main`) | **Fixed: backend #31 merged 2026-10-13**, CI green on `main`. **Tiaan** deploys | Deploy (no migration) | cost-cutting §Side findings |
| 5 | **Loans source of truth**: balances froze and back-logged payments double-counted | **Decided (all recommended, D1c–D4i) and built:** backend **#32** (anchor + nightly roll-forward, migration `7c1e9a4b2d63`) and app **#78** ("Log extra payment", statement date, review banner). **Both merged 2026-10-13.** **Tiaan** deploys the backend **first**, then ships the app in the next release | Deploy, then release | `plans/loans-source-of-truth.md` |
| 6 | **Backups**: install the cron, the `age` key and the off-host target, then run `make restore-check` | **Tiaan** (host root/accounts) | None; **blocks beta invites** | backend #19, runbook |
| 7 | **BACKEND_BIND flip** to `127.0.0.1` and drop the funnel override | **Tiaan** on the host | Several days of 1.0.9 on mobile data first (#1); flipping early cuts off 1.0.8 installs | prebeta memory |
| 8 | **SMTP_\*** in `.env.docker` | **Tiaan** | Pick a provider | qa_pass1 memory |
| 9 | **RA unit-trust questions** (#74 §5), including the RA limit bug (R36k vs 27.5% capped at R350k/R430k) | **Tiaan** answers; **Claude** builds | 3 questions | app #74 |
| 10 | **Play developer account** (~R450 once; new personal account means 12 testers for 14 days before production) | **Tiaan** | Money/identity | pre-beta research |
| 11 | **Information Officer** registration (POPIA) | **Tiaan** | None | pre-beta research, backend #22 |
| 12 | **Operator register Tavily row**: mark it "not configured, no data sent" (verified today) | **Claude** (docs PR) | Tiaan's go | prebeta session |
| 13 | **Optional `COMPOSE_FILE`** in the host `.env.docker`, so a plain `docker compose up` keeps the Funnel override | **Tiaan** (host) | Offered, not answered | qa_pass1 memory |
| 14 | **Local repo housekeeping**: see below | **Claude**, on Tiaan's yes | None | git |
| 15 | **Ollama 5-concurrent-chat latency test; Android 15 notification-capture test** | **Tiaan** (device) / **Claude** (load script) | None | pre-beta research |
| 16 | **Filter-report check** (`/api/detection/filter-report`, `would_drop_real`) | **Claude** can read it if Tiaan shares a token, or **Tiaan** | Auth | sprint-goal memory |
| 17 | **Monetisation** (decided 2026-10-19): Piggybank is meant to earn money; not VAT-registered; distribution stays **sideload only**; R29/mo founding price approved. Paid Pro stays **off** until the beta proves it | **Tiaan** opens a **live PayFast merchant account** (none exists, only sandbox) before any paid launch | Merchant account | `reviews/2026-10-19-founder-pricing-full.md` §6, §11 |

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
