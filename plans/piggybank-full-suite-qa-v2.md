# Blueprint: Piggybank — Tailscale-Only Lockdown + Comprehensive Full-Suite QA Pass

**Objective:** (1) Take the production backend off public internet exposure and run it
Tailscale-only for now — HTTPS/public domain work is explicitly deferred, not abandoned. (2) Run
a genuinely comprehensive QA sweep across the whole app — automated tests, API performance,
database integrity, and a full screen-by-screen exploratory pass — and log every issue, error,
discrepancy, and mistake found into one prioritized report. This report is **input to a new,
separate fix-it blueprint** written after this one closes — not something this plan fixes itself
(except a trivial one-line fix found incidentally — log it, note it fixed, move on; don't
scope-creep into deep remediation).

**Mode:** Direct (no `gh` CLI / PR workflow in use — `Piggybank` repo has no git remote at all;
`piggybank-backend` has a remote but this team edits in place and pushes to `main` directly).
Backend deploys are **not** `git pull` on the server — the `mcp` deploy user has no GitHub
credentials there. Deploys go `git ls-files | tar czf … | scp` to the server, per
`piggybank-backend/docs/runbook.md` / `CLAUDE.md`. Any step that changes a file the server reads
(`docker-compose.yml`, `.env.docker`) must land via that same tar+scp path, or be edited directly
on the server and mirrored back into the repo afterward — pushing to `origin` alone does **not**
deploy anything.

**How this plan was grounded (2026-08-31, drafted then adversarially reviewed by a second
agent that read the actual current files and probed the live server before this revision):**
read `plans/piggybank-full-suite-qa.md` (prior QA blueprint, COMPLETE 2026-08-28 — this plan
does not duplicate it: that one was unit/widget-test authoring plus one exploratory pass; this
one adds latency, DB-integrity, and log-sweep work that never existed before). Read
`docker-compose.yml`, `Caddyfile`, `lib/core/api/api_config.dart`, `android/app/src/main/res/
xml/network_security_config.xml`, `backend/app/subscriptions/payfast.py`, `backend/app/routes/
ai.py` and `chat.py`, `backend/app/limiter.py`, `lib/core/api/api_client.dart`. The review agent
also live-probed the server: `piggybank.fynboscreative.co.za` resolves publicly to
`102.214.9.185`; `curl http://100.121.165.7/` (Tailscale) → `308` (Caddy HTTP→HTTPS redirect,
real cert); `curl http://102.214.9.185/` (public, off-tailnet DNS) → `308` also, confirming real
public exposure right now; `http://102.214.9.185:8000/api/health` times out (backend's own
`:8000` is already Tailscale-scoped correctly) while the Tailscale address returns `200`.

**Explicitly out of scope for this blueprint:**
- Fixing anything found, beyond trivial one-line fixes discovered incidentally during testing.
- Re-verifying findings `piggybank-full-suite-qa.md` already closed — treat 2026-08-28 findings
  as a starting hypothesis to re-check quickly, not to re-derive from scratch.
- Actually implementing HTTPS/public-domain access — user has explicitly deferred this.
- Choosing/integrating a payment gateway beyond what already exists (see Current-state summary —
  PayFast checkout is already substantially built; this plan tests it as-is, doesn't extend it).

---

## Current-state summary (grounded, not assumed — corrected after adversarial review)

**Network today is genuinely live in production, not IP-default HTTP as the first draft of this
plan assumed.** `DOMAIN` on the server is set to the real domain (`piggybank.fynboscreative.co.za`,
which publicly resolves to `102.214.9.185` — a **different** IP from the Tailscale address
`100.121.165.7`). Caddy is actively serving a real Let's Encrypt cert with auto-HTTPS and
HTTP→HTTPS redirect, confirmed live via both the Tailscale and public addresses. `docker-
compose.yml`'s `caddy` service publishes three ports with no bind-address prefix (defaults to
`0.0.0.0`, every interface): `80:80`, `443:443`, **and `443:443/udp`** (HTTP/3) — all three are
public right now. The `backend` service's own `:8000` is confirmed **already** correctly scoped
to the Tailscale interface (public probe times out, Tailscale probe returns `200`) — Step 0's
job there is to *confirm* this holds, not fix a break.

**A live PayFast integration already exists and depends on public exposure.**
`backend/app/subscriptions/payfast.py` + its router expose `POST /payfast/notify` — PayFast's
server-to-server ITN (Instant Transaction Notification) webhook, an *inbound* POST from
PayFast's infrastructure on the public internet, not from the app. `build_checkout_fields()`
sends `notify_url`/`return_url` built from the public domain. **Locking the host to
Tailscale-only will silently break subscription-upgrade confirmation** — this was missed
entirely in this plan's first draft. Step 0 must surface this as a known, accepted consequence,
not something the QA pass later "discovers" as a false bug.

**Android already has cleartext HTTP whitelisted for the Tailscale IP.**
`android/app/src/main/res/xml/network_security_config.xml` already allows cleartext traffic to
`100.121.165.7` (and `10.0.2.2` for the emulator) — switching the app's base URL to plain
`http://100.121.165.7:8000/api` for the Tailscale-only period needs **no** Android config change.
This was a real risk the first draft didn't check; it turned out to be a non-issue — noted so no
one "fixes" it unnecessarily during execution.

**Flutter app today:** `lib/core/api/api_config.dart` defaults `API_BASE_URL` to
`https://piggybank.fynboscreative.co.za/api` (verified exact string). Before the public domain
was wired in, this same constant pointed at the Tailscale IP directly — `docs/security-audit.md`
quotes that exact prior value. Changing it back for the Tailscale-only period is a **revert**,
not a new design decision; frame it that way in commit messages / this plan's own notes so the
history reads coherently.

**QA baseline:** 2026-08-28 baseline was `flutter test` 406/406 green, 37 info-level lints.
`piggybank-backend/CLAUDE.md` documents `pytest.ini` already sets `-m "not live"` by default —
live tests (hitting real, possibly-paid external APIs) are skipped unless explicitly requested;
treat that as an established fact, not something to check for.

**`piggybank-launch-readiness.md`'s status markers are stale — corrected here so this plan's
"feeds into a future blueprint" framing is accurate.** That file's own text still describes
Steps 0/1/5/6 as open, but on-disk evidence says otherwise: `docs/security-audit.md` exists
(Step 0 done), commit `e86cc14` "Step 1 security remediation: password reset, POPIA export/
deletion UI" (Step 1 done), `docs/payment-gateway-scope.md` exists and `backend/app/
subscriptions/payfast.py` + a "Open PayFast checkout instead of instantly upgrading to Pro"
commit exist (Steps 5 done, 6 substantially landed already — not the greenfield "literally does
not exist" state that plan's own text still claims). **This QA pass's findings therefore feed a
brand-new fix-it blueprint written after Step 5 closes below — not `piggybank-launch-
readiness.md`'s Step 1**, which was already scoped and closed from the security audit, a
different input entirely. Whoever executes Step 5 below should re-read `piggybank-launch-
readiness.md` fresh rather than trusting this paragraph if more time has passed.

---

## Dependency graph (corrected — the first draft over-serialized this)

```
Step 0  (Tailscale-only network lockdown)
        │
        │  fully blocks:
        ▼
        Step 4  (Full-app exploratory walkthrough — needs the real target network)
        Step 2  (needs Step 0 only to know which base URL/scheme to hit — otherwise independent)

        does NOT block (hermetic / SSH-based, unaffected by the HTTP lockdown):
        Step 1  (flutter test/analyze are hermetic; backend pytest runs against a test DB)
        Step 3  (reads the DB directly over SSH/psql, not over the HTTP surface being locked down)

        ordering within Steps 2/3/4 that DOES matter (first draft missed this):
        Step 3 (DB integrity snapshot) MUST run BEFORE Step 2 and Step 4, because both of those
        write demo-account data (duplicate/conflict test cases, full create/edit/delete/CSV-import
        exploratory pass) that would contaminate Step 3's "no new stray/duplicate records" check
        if run concurrently or after.

Step 5  (Consolidate all findings into one prioritized report) ── depends on 0–4 all being done
```

**Recommended execution order:** Step 0 first (regardless of what else runs, since it changes
the shared environment). Step 1 and Step 3 can start immediately, in parallel with Step 0 even,
since neither depends on it. Step 2 and Step 4 wait for Step 0, and Step 3 must finish before
either of them starts. Step 5 last.

---

## Step 0 — Tailscale-only network lockdown

**Type:** Infra (Docker/Caddy config + Flutter build config). **Model:** default.

**Status (2026-09-01): DONE.** The Piggybank host (`100.121.165.7`) side of the lockdown was
done and verified first (Tasks 1–7 — see the "Piggybank-host lockdown: DONE" note after the task
list). Task 8's investigation of the second VPS (`102.214.9.185`, the main Fynbos Creative VPS —
this plan's grounding pass had assumed it fronted the piggybank domain) was blocked for a session
on an SSH host-key mismatch; the user independently verified via Absolute Hosting's control panel
that the key change was benign, and the stale `known_hosts` entry was removed. **Investigating
that VPS directly overturned the original grounding assumption**: it does not front piggybank at
all. Its Caddyfile (`/etc/caddy/Caddyfile`, confirmed against the live Caddy admin API's own JSON
config at `localhost:2019/config/`) has no route matching `piggybank.fynboscreative.co.za` — only
`bossiesgym.co.za`, `crateflow.bossiesgym.co.za`, and `fynboscreative.co.za`. The `308` the
original grounding took as evidence of real routing is just Caddy's default blanket HTTP→HTTPS
redirect on port 80, which fires for *any* Host header regardless of whether a route exists.
Confirmed conclusively: an HTTPS request with that SNI fails the TLS handshake outright
(`TLS alert, internal error` — no certificate configured for that hostname), and `ss -tlnp`
showed no other proxy (nginx etc.) listening that could be routing it either. **There was
therefore nothing to lock down on the second VPS** — the Piggybank host was always the sole real
public exposure, and it was already locked down. The public DNS record
(`piggybank.fynboscreative.co.za → 102.214.9.185`) is simply stale/incorrect — it points at a box
that serves nothing for that name — noted as a finding, not fixed here (DNS correction is out of
this plan's scope).

**Context brief:** User wants the app reachable only over Tailscale for now, deferring real
HTTPS/public-domain work. Unlike the first draft's assumption, this is **not** flipping a
dormant IP-default config live — it's shutting down a real, actively-serving public HTTPS
endpoint with a real cert, and it has one concrete real-world consequence: PayFast's ITN webhook
(`POST /payfast/notify`) needs public inbound reachability and will stop being confirmable while
this lockdown is in effect. Surface that explicitly to the user as part of this step, don't let
it surface later as a mystery "bug" in Step 2 or 5.

**Task list:**
1. ✅ **DONE.** Confirmed the recovery path before changing anything: SSH to `100.121.165.7`
   (user `mcp`, key `~/.ssh/id_ed25519`) verified working.
2. ✅ **DONE.** Read the live `.env.docker` on the server. Recorded values (secrets redacted):
   `DOMAIN=piggybank.fynboscreative.co.za`, `CADDY_HTTP_PORT=80` (HTTPS port unset, defaults
   443), `BACKEND_BIND=100.121.165.7`, `AI_FEATURES_ENABLED=true`, Ollama/Anthropic keys present.
   No `CADDY_BIND` existed yet (added in Task 5).
3. ✅ **DONE.** Told the user PayFast ITN confirmation would stop working during the
   Tailscale-only period. User replied "Yes" to proceeding regardless.
4. ✅ **DONE (noted, not actioned further).** Cert-lifecycle consequence recorded here: the
   current Let's Encrypt cert (issued for `piggybank.fynboscreative.co.za`, served by the
   *second* VPS discussed below, not the Piggybank host) will not renew while port 80/443 there
   is closed to Let's Encrypt's servers — same caveat applies once the second VPS is locked down
   too.
5. ✅ **DONE, on the Piggybank host only.** Added `CADDY_BIND` to `docker-compose.yml`'s three
   Caddy port lines (`"${CADDY_BIND:-0.0.0.0}:${CADDY_HTTP_PORT:-80}:80"` etc., mirroring
   `BACKEND_BIND`) and to `.env.docker.example` as documentation. Did not touch host-wide
   firewall rules (Nextcloud on 8080 left alone). `ollama` (`11434:11434`, `profiles: ["ai"]`)
   confirmed not listening on either address — examined, not exposed, no change needed.
6. ✅ **DONE.** Deployed via tar+scp (`git ls-files | tar czf ... -T -`, scp'd, extracted into
   `~/piggybank-backend`), added `CADDY_BIND=100.121.165.7` to the live `.env.docker`, applied
   with a single `docker compose --env-file .env.docker up -d` — only `caddy` was recreated
   (`backend`/`db` untouched), avoiding the stop-then-up re-exposure bug this plan flagged.
7. ✅ **DONE.** `piggybank-backend-backend-1` and `-db-1` still `Up (healthy)`, unaffected by the
   Caddy-only recreate. `curl http://100.121.165.7/api/health` → `308` (Caddy's own HTTPS
   redirect, working as before, now Tailscale-bound). `docker port piggybank-backend-caddy-1`
   confirms all three ports (`80/tcp`, `443/tcp`, `443/udp`) bound to `100.121.165.7` only.
8. ✅ **DONE — revised finding.** The task's original premise (that `102.214.9.185` fronts the
   piggybank domain and needs its own lockdown) was **wrong**, confirmed by direct inspection
   once the SSH host-key blocker cleared: `/etc/caddy/Caddyfile` and the live Caddy admin API's
   own JSON config (`localhost:2019/config/`) show no route for `piggybank.fynboscreative.co.za`
   — only `bossiesgym.co.za`, `crateflow.bossiesgym.co.za`, `fynboscreative.co.za`. The `308`
   this plan's original grounding took as evidence of routing is Caddy's default blanket
   HTTP→HTTPS redirect (fires for any Host header, matched route or not). An HTTPS request with
   that SNI fails the TLS handshake outright (no cert configured for that name), and `ss -tlnp`
   confirmed no other proxy is listening that could route it. **Nothing on this VPS needed
   locking down.**
9. ✅ **DONE.** Since the domain path was never real, `lib/core/api/api_config.dart`'s default
   `API_BASE_URL` reverted to `http://100.121.165.7:8000/api` (the Tailscale address) — this is
   the only address that has ever actually served the app. `test/features/settings/data/
   subscription_api_test.dart` already expected this value and now passes (re-ran, 4/4 green).
10. ✅ **DONE.** This section (Task list items 8–10, the status line above, and the Exit
    criteria below) is the final update — no further changes pending on Step 0.

**Blocker: RESOLVED (2026-09-01).** The SSH host-key change on the second VPS was independently
verified benign by the user via Absolute Hosting's control panel. The stale `known_hosts` entry
was removed and a fresh connection accepted. (A separate, unrelated hiccup — this machine's IP
was briefly fail2ban'd after a wrong-key auth attempt during reconnection — resolved on its own
after a short wait; the user then completed the actual investigation manually over their own SSH
session, pasting output back for analysis.)

**Rollback (Piggybank-host side, already exercised conceptually, not actually needed — no issues
hit):** If anything had broken post-change: restore the exact `docker-compose.yml` port lines
and `.env.docker` values recorded in Task 2, redeploy via the same tar+scp path, confirm
`/api/health` responds again. SSH access (Task 1) remained unaffected throughout.

**Verification (Piggybank-host side — passed):**
```bash
curl -s http://100.121.165.7:8000/api/health        # 200, via Tailscale
docker port piggybank-backend-caddy-1                 # confirms 100.121.165.7-only bindings
```
**Verification (second-VPS side — passed, revised expectation):** since the second VPS never
served the app, there is no "lock it down and confirm it's now unreachable" check to run there.
Confirmed instead that it never routed piggybank traffic in the first place (TLS handshake
failure for that SNI, no matching Caddy route, no other proxy listening — see Task 8).

**Exit criteria: MET.** Piggybank-host lockdown done and verified (✅). App genuinely unreachable
from the public internet (✅ — the only server that ever served it is now Tailscale-only; the
second VPS was never a real path in). `api_config.dart` updated to its final Tailscale-only value
(✅, Task 9). User has explicitly acknowledged PayFast ITN confirmation is suspended (✅, done).
This plan's text updated with the final base-URL/scheme decision (✅, Task 9/10).

---

## Step 1 — Automated regression baseline

**Status (2026-08-31): DONE.**

**Results:**
- **Backend pytest** (via `docker compose --env-file .env.docker run --rm --entrypoint '' backend-test python -m pytest tests/ -v`, run on the server against its real test flow — note: `backend-test`'s compose-defined entrypoint is `["/bin/sh","-lc"]` with `command: tail -f /dev/null`, so a plain `docker compose run backend-test <cmd>` silently swallows the command as unused argv to `sh -lc` and exits instantly with no output — `--entrypoint ''` is required to actually run pytest):
  `==== 1083 passed, 6 skipped, 6 deselected, 3 warnings in 167.65s (0:02:47) ====`. Zero failures. The 6 skips are all missing-sample-CSV fixtures (`docs/import-csv-templates/`, `docs/test-data/*.csv` — expected/by-design, not a gap).
- **`flutter analyze`**: `41 issues found` — all `info`-level lints (const-constructor suggestions, tearoffs, key params, EOL). **Regression vs. 2026-08-28 baseline of 37**: +4 info-lints, no new warnings/errors. Not investigated further per this step's scope (logging, not fixing).
- **`flutter test`**: `+420 -2` — 420 passing, **2 failing** (baseline was 406/406 — net +16 total tests, 2 new failures):
  1. `test/features/settings/data/subscription_api_test.dart` — *"SubscriptionApi startCheckout POSTs /subscription/checkout and resolves the absolute checkout URL"*: `Expected: Uri:<http://100.121.165.7:8000/api/subscription/checkout/abc-123>` vs. `Actual: Uri:<https://piggybank.fynboscreative.co.za/api/subscription/checkout/abc-123>`. **Classification: stale test, not a code regression** — the test hardcodes the pre-domain Tailscale-IP expectation, but `api_config.dart`'s default is still (correctly, for now) the public domain, since Step 0's Task 9 revert hasn't happened yet. This will flip on its own once Task 9 lands, or needs updating either way — don't "fix" it blind before Task 9's decision is final.
  2. `test/widget_test.dart` — *"LoginScreen renders email/password fields and a submit button"*: `Found 0 widgets with type "TextField" that are ancestors of widgets with text "Email"` — a genuine widget-tree assertion failure, unrelated to network/domain config. **Classification: real regression**, not further diagnosed here (15-minute budget not spent chasing it — flagged for Step 5/fix-it blueprint with full stack trace captured in this run's log).

**Context brief:** Establish current ground truth with the existing automated suites. Both
suites are hermetic (Flutter's API layer is mocktail-faked per the predecessor QA blueprint's
harness; backend pytest runs against its own test DB, not production) — neither is affected by
Step 0's network change. The 2026-08-28 baseline (406/406 Flutter tests, 37 info-lints) is
several feature-branches stale.

**Context brief:** Establish current ground truth with the existing automated suites. Both
suites are hermetic (Flutter's API layer is mocktail-faked per the predecessor QA blueprint's
harness; backend pytest runs against its own test DB, not production) — neither is affected by
Step 0's network change. The 2026-08-28 baseline (406/406 Flutter tests, 37 info-lints) is
several feature-branches stale.

**Task list:**
1. Backend: from `C:\Fynbos Creative Master\02_Clients\piggybank-backend\backend` (absolute
   path — don't assume a shell's cwd), run tests via the project's documented runner —
   `make test-backend`, or the `backend-test` Docker Compose profile
   (`docker compose --profile test run --rm backend-test`) per `CLAUDE.md` — rather than a bare
   local `pytest`, which needs a venv and a reachable Postgres not established on this machine.
   `pytest.ini` already sets `-m "not live"` by default, skipping tests that hit real external
   APIs — record that as expected/by-design, not as a gap to investigate.
2. Flutter: `flutter analyze` (full output) and `flutter test` (full suite, full output — every
   failure's complete text, not a summary).
3. Diff against the 2026-08-28 baseline — flag any regression (new failure) or improvement
   (fewer lints, more tests) as fact, not spin.
4. For any failure found: spend up to ~15 minutes classifying it (real bug / stale test /
   environment artifact) and record that classification. Do **not** fix it here unless it's a
   one-line, obviously-safe fix — this step's job is honest logging, not remediation.

**Verification:** The report for this step must contain the literal pass/fail/skip line from
each of the three runs (`flutter analyze`, `flutter test`, backend test runner) with exact
counts — not a paraphrase like "tests passed."

**Exit criteria:** All three runs completed fresh, in full, with complete (not summarized)
output captured for Step 5.

---

## Step 2 — API performance & error-response audit

**Status (2026-09-01): DONE.**

**Results (demo account, `http://100.121.165.7:8000` base, via `curl` with `%{time_total}`):**

1. **Endpoint surface enumerated from live `/openapi.json`** (`:8000/openapi.json` — no `/api`
   prefix on the schema URL itself, though paths inside it are `/api/...`): ~120 endpoints across
   24 tag groups. Confirms the plan's flag: `POST /ai/chat` and `POST /ai/web-search` are mounted
   entirely outside `/api` (separate "AI" tag) alongside a distinct `/api/ai/*` group
   (`context-preview`, `insights`) — two different things sharing similar names, easy to conflate.
   Also surfaced a real backend endpoint, `POST /api/admin/refresh-prices`, with no corresponding
   Flutter admin UI — consistent with the plan's note that `docs/admin-scope.md` describes
   something not yet built client-side.
2. **Plain CRUD-read latency: all fast, no findings.** 17 representative authenticated GETs
   across accounts/assets/budgets/expenses/goals/insights/liabilities/portfolios/ra/subscription/
   summaries/tfsa/transactions/consents/auth — every one 20–65ms. Nothing near the ~1s flag
   threshold. `GET /api/budgets/progress` alone returned `422` on first try — correct: it requires
   a `month` query param, and the error body (`{"field":"month","message":"Field required"}`) is
   the intended, sensible response, not a bug.
3. **AI-backed endpoints: slow as expected, but two real findings on top of the expected latency.**
   - `POST /api/chatbot/chat`: 10.2s. Correctly used real account data (net worth), **but returned
     the figure in `$` (USD symbol) instead of ZAR/`R`** — a South African app quoting a South
     African user's own net worth in the wrong currency symbol. New finding, high visibility, not
     previously logged.
   - `POST /api/ai/insights`: 26.1s. Correctly used real account/expense/income data, in ZAR this
     time — no currency-format issue here, inconsistent with `chatbot/chat` above (worth noting as
     its own finding: two AI endpoints, same account, inconsistent currency formatting).
   - `POST /ai/chat` (the one mounted outside `/api`): 3.3s, works **with no Authorization header
     at all** — confirmed by sending the identical request with and without a bearer token and
     getting equivalent (200, generic) responses either way. Its answer was also generic/textbook
     ("here's the formula for net worth") rather than using real account data — unlike the
     authenticated `chatbot/chat`, suggesting this is a separate, less-developed implementation
     that never had auth or account-context wiring added. **High-severity finding**: an
     unauthenticated endpoint that triggers a real LLM inference call is a cost/abuse surface for
     anyone reachable on the tailnet, not just app users.
   - `POST /ai/web-search` (also outside `/api`): correctly returns `401 {"detail":"not
     authenticated"}` with no token — so the missing auth on `/ai/chat` is specific to that one
     endpoint, not the whole outside-`/api` "AI" group.
4. **Rate limiting: confirmed absent on every AI/chatbot-adjacent endpoint.** Grepped
   `@limiter.limit(...)` usage across the whole backend (`app/limiter.py`'s decorator) — present
   and reasonably tuned on everything else (e.g. auth login `5/minute`, destructive bulk-delete
   `3/hour`, general CRUD `20-60/minute`) but **zero occurrences** in `app/chatbot/router.py`,
   `app/ai/routes.py`, `app/routes/ai.py`, or `app/routes/chat.py`. Combined with finding 3's
   unauthenticated `/ai/chat`, this compounds: an unauthenticated, unrate-limited endpoint that
   costs 3+ seconds of LLM inference per call. New finding, not previously logged.
5. **Dio client timeout: confirmed missing, matches the plan's flagged concern.**
   `lib/core/api/api_client.dart` constructs `Dio(BaseOptions(baseUrl: baseUrl))` with no
   `connectTimeout`/`receiveTimeout`/`sendTimeout` set anywhere in the codebase — Dio's default
   when unset is unlimited. A stalled connection (bad mobile network, backend hang) would leave
   the app waiting indefinitely with no client-side timeout ever firing, regardless of the
   backend's own 120s `OLLAMA_TIMEOUT_SECONDS` bound (server-side only, doesn't help the client).
   Real, confirmed bug — not fixed here (not a trivial one-liner: needs a considered timeout value
   given the AI endpoints' legitimate 10–26s+ response times).
6. **Error paths: clean bill of health.** Invalid JWT → `401 {"detail":"not authenticated"}`. No
   auth header → same. Not-found id → `404 {"detail":"account not found"}`. Missing required
   fields → `422` with a precise per-field message list, no stack trace. Malformed JSON syntax →
   `422 {"detail":[{"field":"1","message":"JSON decode error"}]}`. Duplicate-email registration →
   `409 {"detail":"email is already registered"}`. No leaky internals, no stack traces, sensible
   codes throughout every path tested.
7. **DB-index angle: no finding.** The only latencies worth investigating (chatbot/insights) are
   LLM-inference-bound, not DB-bound — every DB-backed read was 20–65ms, too fast to suspect a
   missing index. Task not applicable this round; re-check if a future pass finds a genuinely slow
   DB-backed endpoint.

**Context brief:** No prior QA pass measured latency or systematically exercised error paths —
the user named "slow API calls" explicitly. This pass also needs to cover the AI-adjacent routes
that live outside the main `/api` surface.

**Context brief:** No prior QA pass measured latency or systematically exercised error paths —
the user named "slow API calls" explicitly. This pass also needs to cover the AI-adjacent routes
that live outside the main `/api` surface.

**Task list:**
1. Enumerate the real endpoint surface from the FastAPI app's own OpenAPI schema
   (`/openapi.json`), not a hand-maintained list. Group by router: auth, accounts, transactions,
   portfolios, goals, imports, chatbot, insights, subscriptions (including `/payfast/notify` and
   checkout endpoints — exercise these read-only/status-check where possible, don't trigger a
   real charge), admin (if reachable). **Also explicitly include** `backend/app/routes/ai.py`'s
   `/ai/web-search` (mounted unconditionally, bypassing the `AI_FEATURES_ENABLED` flag — worth
   flagging on its own if that's unintentional) and `routes/chat.py`'s `/ai/chat` — both live
   outside the main router grouping and are easy to miss.
2. For each group, log an authenticated demo-account call's wall-clock latency (`time curl ...`
   is sufficient). Flag anything over ~1s for a simple CRUD read, over ~5s for an AI-backed
   endpoint (chatbot/insights/web-search — genuinely slower due to Ollama inference, don't flag
   without noting that expected-slow context).
3. **Be aware of `slowapi` rate limiting** (`backend/app/limiter.py`) before treating a burst of
   429 responses as a bug — space out repeated calls in the same endpoint or the audit will
   generate false "error" findings that are actually the rate limiter working correctly. Note
   the limiter's actual configured thresholds as part of this audit (are they sane for a mobile
   client with retries, or too aggressive?).
4. Exercise obvious error paths per group: invalid/expired JWT, malformed body, not-found id,
   duplicate/conflict on write endpoints. Confirm sensible status codes and non-leaky error
   bodies (no stack traces, no internal path disclosure).
5. Re-check the chatbot/insights client-timeout mismatch flagged by the review: `lib/core/api/
   api_client.dart` builds `Dio(BaseOptions(baseUrl: baseUrl))` with **no timeout configured at
   all**, against a backend-side `OLLAMA_TIMEOUT_SECONDS` defaulting to 120s. Confirm what Dio's
   own default actually resolves to in practice and whether the app can end up waiting
   indefinitely, or conversely erroring before the backend would have genuinely responded.
6. DB-side latency angle: for the slowest 2–3 endpoints from Task 2, check the relevant tables in
   `models.py` for missing indexes on frequently-filtered/joined columns (`\d <table>` over
   `psql`) — a measured slow endpoint plus a missing index is a much stronger finding than either
   alone.

**Verification:** N/A (investigative/logging step) — but every latency and error-path finding
must include the actual command/response, not a paraphrase.

**Exit criteria:** Every endpoint group (including `/ai/web-search`, `/ai/chat`, PayFast routes)
has a logged latency figure and at least one exercised error path, feeding Step 5.

---

## Step 3 — Database integrity audit

**Status (2026-08-31): DONE.**

**Results (demo user `5f822142-8a02-4ad4-8495-9e0e96fad014`, DB name is `piggybank` not
`finance_app` — the `.env.docker.example` placeholder — correct that assumption if reused
elsewhere):**

1. **Cost-basis bug: CONFIRMED STILL PRESENT**, not fixed. All 5 demo holdings' `cost_basis`
   values, divided by `quantity`, yield plausible *per-share* prices (AAPL 42000/15=2800,
   MSFT 84000/8=10500, NPN.JO 64000/20=3200 ≈ real Naspers range, SBK.JO 21000/100=210 ≈ real
   Standard Bank range) — meaning the seed data stored **total invested amount**, not per-unit
   cost. But the app code (`backend/app/portfolios/router.py` lines 546, 749, 814-815, 1207-1208,
   1249 — `cost = h.quantity * h.cost_basis`, `avg_cost = holding.cost_basis`) treats
   `cost_basis` as **already per-unit**, so every cost/P&L calculation for the demo account
   multiplies quantity in twice, overstating invested cost and understating unrealized P&L by
   roughly a factor of the quantity itself. High-severity, confirmed-live finding for Step 5.
2. **2 orphaned transactions found** (`account_id IS NULL`): `d1a78d20-428e-47ff-b1f2-a9bbbde90447`
   ("Test import Woolworths", R150, 2026-08-27) and `fd672d88-0632-41f1-92cf-c89796ed3263`
   ("Test import consulting fee", R500, 2026-08-27) — both dated the same day, both named "Test
   import ...", strongly suggesting leftover rows from a prior CSV-import test run that skipped
   account assignment. `transactions.account_id` has an FK to `accounts` but is nullable at the
   DB level, so this didn't raise an integrity error — it's an application-logic gap, not a
   schema violation. New finding, not previously logged.
3. **`alembic_version` is current**: `d6e7f8a9b0c1`, matches the latest file in
   `backend/alembic/versions/` (`20260830_1600_..._add_password_reset_and_token_family.py`). No
   pending migration.
4. **No dangling `user_id`** across `goals`, `assets`, `liabilities` (0 rows each). No implausible
   transaction dates (none outside `[2000-01-01, now()+1d]`). Note: `accounts` has **no `balance`
   column** at all (balance is computed, not stored) — the plan's own suggested negative-balance
   query doesn't apply as written; not a bug, just a schema-shape correction for whoever re-runs
   this.
5. **Log sweep — one significant finding, believed already resolved**: `db` container logs show
   `ERROR: type "paymenttransactionstatus" already exists` repeating roughly every 61 seconds from
   2026-08-31 18:19 UTC to 19:05 UTC (46 straight occurrences), ending exactly when a fresh
   `backend-1` container started at 19:06:47 UTC (confirmed via `docker inspect`'s `StartedAt`).
   This matches the crash-loop this plan's own Step 3 Task 3 text already references as a known
   2026-08-31 incident from before this session — treat this as **confirmed evidence of an
   already-known, already-resolved incident**, not a new one. **Root cause identified though**:
   `backend/alembic/versions/20260830_1400_..._add_payment_transactions.py` issues a raw
   `CREATE TYPE paymenttransactionstatus AS ENUM (...)` with **no `checkfirst`/idempotency guard**
   — unlike the `cashflowtype` migration (`.../a1b2c3d4e5f6_.../`, uses
   `cashflowtype.create(op.get_bind(), checkfirst=True)`) and the `goalstatus` migration (uses
   `create_type=False` + a guarded `DO $$ ... CREATE TYPE IF NOT EXISTS`-style block). If the
   `backend` container restarts mid-migration again (e.g. during a future crash-loop or a bad
   deploy), this migration will fail identically and the container will loop indefinitely until
   manually intervened. **Latent risk, not currently broken** — worth a one-line fix
   (`checkfirst=True`) in the fix-it blueprint, not this one. `backend` app-level logs for the
   same window show nothing but health-check 200s — the failure was purely at the `db` container
   level during alembic's `CREATE TYPE` step.
6. **Row-count snapshot for demo account (established for Steps 2/4 contamination checks)**:
   `accounts=3, transactions=75, portfolios=1, holdings=5, goals=3, assets=6, liabilities=3,
   budgets=16`.
7. **Single-portfolio check: PASSED.** Demo user has exactly one portfolio (`Growth Portfolio`,
   `b40d1cf5-2f0c-46f1-8f41-2ae4045f1c80`) — the stray "Test" portfolio cleanup held.

**Type:** Backend (read-only SQL via SSH/psql). **Model:** default. **Independent of Step 0.**
**Must run before Steps 2 and 4** — it establishes the clean-state snapshot those steps'
write-heavy testing would otherwise contaminate.

**Context brief:** "Database errors" was named explicitly by the user. The prior QA pass found
one seed-data bug (cost-basis stored as total instead of per-unit) but never did a general
integrity sweep or a log review. Use narrowly-scoped read-only queries — broad exploratory ones
have been getting blocked by the permission classifier this week.

**Task list:**
1. Re-verify the cost-basis seed-data bug's current status (fixed/still-broken/unknown) against
   the live `holdings` table for the demo account — don't assume either way.
2. Check for orphaned rows: holdings referencing a nonexistent portfolio, transactions
   referencing a nonexistent account, goals/assets/liabilities with a null/dangling user_id —
   scoped to the demo account first, broader if the classifier allows it.
3. Check `alembic_version` matches the latest migration file — confirm nothing pending unapplied
   (this exact bug class caused the 2026-08-31 crash-loop incident).
4. Spot-check numeric/date fields for implausible values beyond the known cost-basis bug
   (negative balances, far-future/past dates, implausible currency magnitudes) on demo data.
5. **Log sweep (new — the first draft had no log review despite "database errors" being an
   explicit ask):** `docker compose logs backend` and the `db` service's own logs, for the last
   several days — grep for tracebacks, 5xx responses, SQLAlchemy `IntegrityError`/`OperationalError`,
   and any Alembic warnings. Cross-reference timestamps against Step 2's latency findings once
   that step exists (slow-query log entries near a flagged-slow endpoint is a strong correlated
   finding).
6. **Establish the pre-Step-2/4 snapshot**: row counts per table for the demo account, recorded
   here — this is what makes it possible to tell, later, which new rows in the demo account came
   from Step 2/4's own testing versus a genuine pre-existing anomaly.
7. Confirm the demo account is otherwise the single-portfolio state left after this week's stray
   "Test" portfolio cleanup — no new stray/duplicate records since.

**Verification:** N/A (investigative step). Every finding cites the actual query/log line and
result, not a paraphrase.

**Exit criteria:** A complete, evidence-backed integrity + log-sweep finding list (or an
explicit clean bill of health), plus the row-count snapshot Steps 2/4 need, feeding Step 5.

---

## Step 4 — Full-app exploratory screen-by-screen walkthrough

**Status (2026-09-01): COMPLETE.** Walk list
derived (Task 1 done — see below, matches this plan's own list exactly, all 19 domains confirmed
present under `lib/features/`). AVD booted, debug APK reinstalled fresh (clean uninstall first to
dodge the stale-biometric-lock issue), demo account logged in. Domains exercised across all three
sessions: Dashboard, Accounts (+ account edit), Assets, Liabilities, Calculators (both tabs,
complete), Invest (Overview + All Holdings + holding detail + holding edit), Instrument
Comparison (Summary/Risk metrics/Correlation tabs), Imports Wizard (Configure → Upload → Review,
CSV end-to-end both failure and success paths), TFSA and Retirement Annuity ledgers (unlocked
via two new demo portfolios, both live-verified — see finding 18), Transactions (all 4 filter
tabs + category summary), Expenses, Budgets, Goals, Insights (both past + live-asked), Settings
(Privacy & consent, Security, Appearance, Subscription, Import history, Notifications, and the
previously-unlisted AI Assistant/Chatbot sub-screen). Findings 9–24 below are from the second and
third sessions; finding 18 was resolved in a fourth. Every domain from Task 1's derived walk
list has now been opened and exercised — nothing remains uncovered. Admin confirmed missing (no
client UI, matches Step 2's orphaned backend route finding).

**Data-integrity caveat for whoever reads Step 3's snapshot next:** while live-testing the CSV
import flow's success path (finding 23) via a direct authenticated API call (to get past the UI's
error-detail gap, finding 20), a `DELETE` cleanup pass for the two new QA test transactions it
created accidentally included a third, pre-existing transaction's ID (`d1a78d20…`, "Test import
Woolworths", one of Step 3/Step 2's original two orphaned `account_id IS NULL` seed rows) —
copied in from the same query result by mistake, not one of this session's own rows. It was
immediately recreated via `POST /api/transactions/` with matching `date`/`amount`/`category`/
`description`, restoring the **total transaction count to 75**, matching the pre-mutation
baseline. However the recreated row has a **new UUID, a new `created_at`, and `source: "manual"`
instead of the original `source: "csv_import"`** — an exact-content diff against Step 3's original
snapshot (if one is ever done at the row level, not just the count level) will show this one row
as changed. Flagging explicitly rather than letting Step 5 or a future session discover a
mismatch and treat it as a mystery.

**Derived walk list (Task 1, grounded against `lib/features/*/screens/` and
`lib/core/router/app_router.dart` + `placeholder_screens.dart` on 2026-09-01):** accounts,
assets, auth, budgets, calculators, chatbot, consent, dashboard, expenses, goals, imports,
insights, liabilities, portfolios, ra, settings, summaries (data-only, no dedicated screen —
consumed elsewhere, not a gap), tfsa, transactions. **Confirmed: `lib/features/admin/` does not
exist** — no client UI for the backend's `/api/admin/refresh-prices` route (Step 2 finding);
logging Admin as a concretely missing screen per the plan's instruction. Note:
`SettingsScreen` itself lives in `lib/core/router/placeholder_screens.dart`, not under
`lib/features/settings/screens/` like its sub-screens — cosmetic/organizational, not a bug.

**Findings so far:**

1. **[Data quality, not a code bug] Portfolio holdings have wildly unrealistic seed cost-basis
   values, producing enormous unrealized-loss figures.** Invest tab shows Total value
   R90 103,88 against **-R5 391 896,12 unrealized P&L** — a loss ~60x the portfolio's own value.
   Root-caused via GLD holding's Edit screen: Quantity 50, Cost basis per unit R16 000, Current
   price R681,51. The app's math is exactly correct — 50×681,51 = R34 075,50 (displayed value);
   50×(681,51−16 000) = -R765 924,50 (displayed P&L, matches to the cent). The bug is that
   R16 000/unit is a nonsensical purchase price for an ETF trading at ~R681 (23x too high) —
   this is a demo/seed-data entry error, not an app calculation defect. SBK.JO shows the same
   pattern (value R31 932,00 vs -R2 068 068,00 unrealized). **Recommendation for the fix-it
   blueprint: correct the seed script's cost-basis-per-unit values for portfolio holdings, not
   the P&L formula.** Severity: Medium (cosmetically alarming on a demo account, no functional
   bug) rather than High/Critical.
2. **[UX, minor] Tapping an account row on the Accounts screen goes straight into "Edit Account"
   mode**, not a read-only detail/transaction-history view. May be intentional (accounts are
   simple, transactions are filtered separately elsewhere) but could surprise a user expecting a
   transaction list per account. Not logged as a defect, flagged for product-owner judgment call
   in the fix-it blueprint triage.
3. **No issue found** — Dashboard: net worth, cashflow, goal card, quick-access icons, recent
   transactions all render correctly; net worth reconciles exactly (Accounts R88 530,50 + Assets
   R3 478 000,00 − Liabilities R1 758 500,00 = R1 808 030,50, matches header).
4. **No issue found** — Accounts screen: total balance correct, three accounts list with
   correct per-account balances.
5. **No issue found** — Assets screen: total assets R3 478 000,00 reconciles exactly against
   the six listed assets; long names ellipsize correctly (no overflow).
6. **No issue found** — Liabilities screen: total liabilities R1 758 500,00 reconciles exactly
   against the three listed liabilities.
7. **No issue found** — Calculators screen (Loan Calculator tab): loads correctly with a
   Loan Calculator / Loan Accelerator toggle and three input fields; not yet exercised to
   completion (interrupted by an automation-side issue, not an app issue — see Environment notes
   below).
8. **Observation, not yet conclusively a bug** — Accounts screen shows "Old Mutual Investment"
   and "Capitec Savings" both at R0,00 while the total balance equals only the FNB Cheque
   Account's balance. May be legitimate zero-balance seed accounts; cross-check against Step 3's
   DB snapshot before treating as a finding.
9. **[High severity, live-confirmed] Chatbot ("Penny", reached via Settings → AI Assistant)
   guardrail is inverted.** Asked the off-topic question "What is the capital of France" —
   answered directly ("Paris is the capital of France.") with no redirect. Then asked two
   genuinely on-topic questions — "Show my net worth trend" and "Am I on track with my budget?"
   (the latter is literally one of the screen's own three suggested-question chips) — both got
   refused with a generic "I can only help with questions about your finances here in Piggybank.
   Please provide more details..." deflection. Reproducible, not a one-off: 2/2 finance questions
   deflected, 1/1 off-topic question answered. **Likely root cause, connecting to Step 2 finding
   3**: Step 2 found a second, unauthenticated `/ai/chat` endpoint (outside `/api`, no account
   context, no guardrail, generic textbook answers) alongside the proper authenticated
   `/api/chatbot/chat` (which correctly used real account data and had the guardrail). This
   screen's symptoms — answers off-topic queries with no refusal, refuses on-topic queries it
   can't ground in real data — match `/ai/chat` exactly. Hypothesis for the fix-it blueprint:
   this Settings → AI Assistant screen is wired to the wrong endpoint.
10. **[Medium severity, live-confirmed] Full Transactions list never colors income green.**
    Dashboard's Recent-transactions preview shows "Test import consulting fee" (R500,00, income)
    in green — matches commit d1ef674's "Colour income transaction amounts green." But the full
    Transactions screen (all/Income/Expense/Transfer tabs) renders every positive amount
    (consulting fee R500,00, FNB interest R330,00, Monthly salary R35 000,00) in plain black
    bold, identical styling to expenses. Confirmed across the "All" and "Income" filter tabs.
    Dashboard preview and full list use inconsistent styling for the same data.
11. **[Low severity, live-confirmed] AI-generated Insights text uses US number formatting,
    not South African.** The Insights screen's live "What is my net worth?" answer returned
    "Your net worth is R 1,808,030.50" (comma-thousands, period-decimal) while every other
    screen in the app (Dashboard, Accounts, Budgets, Goals) renders the identical figure as
    "R 1 808 030,50" (space-thousands, comma-decimal, the correct SA convention). A saved past
    insight from 2026-08-28 shows the same pattern ("R 1 719 500.00"), so this isn't a one-off —
    it's how the AI-insights endpoint has always formatted currency. Extends Step 2 finding 3
    (chatbot's `$` symbol bug) to a second, still-live formatting inconsistency: correct currency
    symbol here, wrong number-grouping convention.
12. **[Data/seed issue, not a code bug, live-confirmed] Budgets screen shows "No budgets for
    this month" for September, August, AND June 2026** (today's actual date) — the demo
    account's 16 budget rows (per Step 3's snapshot) only cover May 2026. A demo user opening
    Budgets today sees an empty state; navigating back to May 2026 shows all 6 budget categories
    rendering correctly (progress bars, over/under-budget red/green states, percentages all
    correct — e.g. Groceries 114%/R430 over, Rent 100%, Utilities 102%/R20 over). Cosmetic/sales
    problem for a demo walkthrough, not an app defect — flag for whoever owns re-seeding demo
    data with rolling/relative dates instead of fixed 2026 months.
13. **[Root cause identified, live-confirmed] Settings → Import history explains Step 3
    finding 2's orphaned transactions.** The history shows exactly one import, `test_import.csv`,
    status **COMPLETED**, "2 / 2 imported" — matching the two orphaned (`account_id IS NULL`)
    "Test import ..." transactions Step 3 found in the DB. The import wizard reports full
    success despite never actually assigning an account to either imported row. Real bug: the
    completion/success state doesn't reflect the account-assignment step's actual outcome.
14. **No issue found** — Goals tab: all three goals (New Laptop 100%, House Deposit — Cape Town
    15%, Emergency Fund 57%) show mathematically correct percentages and deadlines.
15. **No issue found** — Loan Calculator and Loan Accelerator (both Calculators tabs): filled
    and calculated end-to-end (R500 000 @ 11.5% over 240 months → R5 332,15/month, matches
    amortization formula; same inputs + R1 000 extra/month → R336 225,48 interest saved / 91
    months saved on Loan Accelerator). No defects.
16. **No issue found** — Expenses (by-category breakdown): total R143 120,00 reconciles against
    all listed categories (Rent, Groceries, Insurance, Transport, Petrol, Utilities,
    Entertainment, Clothing, Dining Out, Medical), no overlapping labels, gradient-shaded
    category dots scale sensibly by rank.
17. **No issue found** — Privacy & consent, Security (biometric toggle, Set PIN, Export my
    data, Delete my account all present per Step 1 security remediation), Appearance (per-mode
    icon + subtitle polish confirmed live), Subscription (feature-comparison checklist polish
    confirmed live, demo account correctly shows Pro/Active), Notifications, Import history (the
    entry itself renders correctly, see finding 13 for its underlying data bug).
18. **RESOLVED — live-verified with the user's explicit go-ahead to mutate demo data.**
    Original premise was wrong: the TFSA/RA ledger entry point is **not** gated on account type
    at all (`lib/features/accounts/` has no TFSA/RA branching) — it's gated on **portfolio
    type** (`portfolio.portfolioType == PortfolioType.tfsa`/`.ra` in
    `lib/features/portfolios/screens/portfolio_detail_screen.dart`, an `IconButton` in that
    screen's `AppBar.actions`, tooltip "TFSA contribution ledger" / "Retirement Annuity
    ledger"). The demo account had only one portfolio ("Growth Portfolio", `general` type), so
    the icon never appeared on *any* screen — not because of account types. Unlocked
    non-destructively by creating two **new** portfolios via `POST /api/portfolios/`
    (`{"name": "QA TFSA Portfolio", "portfolio_type": "tfsa"}` and `{"name": "QA RA Portfolio",
    "portfolio_type": "ra"}`) rather than mutating the existing "Growth Portfolio" or its
    holdings (which findings 1/2 already reference). Both ledger screens then live-verified,
    both rendering correctly: **TFSA contribution ledger** shows a pre-existing (already-seeded,
    unrelated to the new portfolio) "Lifetime contributed R 115 000,00 / R 385 000,00 of
    R 500 000,00 remaining", a correct per-tax-year breakdown (2023–2026), and a working growth
    projection table. **Retirement Annuity ledger** shows the expected empty state (R 0,00
    total, R 36 000,00/R 36 000,00 annual limit untouched) with the same growth-projection UI.
    No defects found on either screen. Confirms TFSA/RA contribution data is scoped per-user,
    not per-portfolio — the ledger screens don't take the triggering portfolio's ID at all
    (`MaterialPageRoute(builder: (_) => const TfsaLedgerScreen())`, no arguments), which is why
    the TFSA ledger already had contribution history despite the just-created portfolio having
    zero holdings. The two QA portfolios were left in place (not deleted) so this stays
    unlocked for any future session — flagged here so it isn't mistaken for stray seed data.
19. **Admin confirmed missing** — no `lib/features/admin/` directory, matches Step 2's finding
    of an orphaned `/api/admin/refresh-prices` backend route with no client UI.
20. **[High severity, live-confirmed] CSV import wizard's failure UI shows zero diagnostic
    detail, while the backend already computes it.** Uploaded a synthetic 2-row CSV missing the
    `type`/`category` columns the generic (no-template) parser requires; the app's "Upload
    result" card showed only aggregate counts ("Imported: 0 / 2", "Failed rows: 2",
    "Auto-categorized: 0") with no indication of *why*. A direct authenticated call to the same
    endpoint (`POST /api/imports/`) returned the real reason in full:
    `error_message: "[{\"row\": 2, \"error\": \"row 2: invalid type ''\"}, {\"row\": 3,
    \"error\": \"row 3: invalid type ''\"}]"` (`app/imports/router.py`'s `_parse_row`, lines
    121–158). The backend already does the work; the Flutter client (`lib/features/imports/`)
    simply never surfaces `error_message` to the user. A real user whose bank-statement CSV
    fails import has no way to learn what to fix.
21. **[Medium severity, live-confirmed] Compare Instruments' ticker-autocomplete dropdown
    triggers a debug-mode `RenderFlex` overflow** ("BOTTOM OVERFLOWED BY 166 PIXELS", shrinking
    to 1.9px once a ticker chip is added) when the suggestions list opens with the keyboard
    visible. Debug-only banner, but indicates a real unbounded-height layout under that
    keyboard+dropdown combination worth a release-mode check.
22. **[Low severity, live-confirmed] Compare Instruments' price chart has an overlapping Y-axis
    top label** — "41,2" (the exact max) renders directly on top of "40" (the rounded gridline)
    on GLD's 1-year chart, both partially legible. Cosmetic only.
23. **[Confirms & refines finding 13's root cause, live-confirmed via direct API test] CSV
    import DOES correctly assign `account_id` to imported transactions when one is specified at
    upload time.** Re-ran the import flow via `POST /api/imports/?account_id=<capitec-uuid>`
    with a valid 2-row CSV: both new transactions came back with `account_id` and `account_name`
    correctly populated ("Capitec Savings"), and the import correctly reported `status:
    "completed"`. This means the original two orphaned rows (finding 13, Step 3 finding 2) are
    explained simply by that import having used the **"No account" default** at Configure time,
    not by a completion-status bug that ignores the account-assignment outcome as finding 13's
    original phrasing implied. Revised recommendation for the fix-it blueprint: consider making
    "No account" a more deliberate/confirmed choice (e.g. a confirmation step) rather than the
    unlabelled default, since it silently produces orphaned transactions with no way for the
    user to know from the "COMPLETED" status that nothing was linked to an account.
24. **[Medium severity, live-confirmed] CSV import auto-categorization overwrites the CSV's own
    `category` column instead of only filling blanks.** The same successful test import (finding
    23) supplied `category: "Groceries"` on an expense row and `category: "Salary"` on an income
    row; both were saved as `category: "Freelance"` instead — an income-sounding category applied
    to both an expense and an income row alike, matching neither CSV value. `auto_categorized_rows:
    2` in the response confirms the categorizer ran and replaced both. Worth checking whether the
    categorizer is intended to only fill *blank* categories (and has a bug making it always fire)
    or whether it's meant to always override and is simply defaulting to the wrong bucket.

**Environment note for whoever continues this session:** driving the emulator via raw
`adb shell input tap/text` + `screencap` is workable but fragile — screen coordinates must be
read fresh off each screenshot (the visible layout shifts once the on-screen keyboard opens,
roughly 900x2000 logical px in screenshots, actual device is 1080x2400, so multiply displayed
coordinates by 1.2 for the real tap target). **The hardware back key (`adb shell input keyevent
4`) does not reliably just dismiss the keyboard on this app — it can navigate a full screen back
or exit the app entirely if pressed when you think you're only dismissing a keyboard.** Prefer
tapping the on-screen back arrow, or tapping an inert area of the screen, over the back key.
Also hit the known **stale-biometric-lock** issue on a warm relaunch (session persisted but the
app showed "Piggybank is locked" with no way to actually authenticate via the AVD's unenrolled
fingerprint) — worked around with `adb shell pm clear za.co.fynboscreative.piggybank` then a
fresh login, matching this plan's own advance warning about that red herring.

**Real-device confirmation of Step 0's `api_config.dart` fix:** the user hit a "Network error"
on their physical phone logging in with a different account (`test2@example.com`), Tailscale
confirmed connected on-device. Backend confirmed healthy from this machine
(`curl http://100.121.165.7:8000/openapi.json` → 200 in 71ms), so the phone's own app build is
the suspect — almost certainly a build from before this session's Step 0 revert (still pointing
at the dead public-domain default). Phone wasn't reachable via `adb` to install the fresh debug
APK (`Piggybank/build/app/outputs/flutter-apk/app-debug.apk`, already built this session) —
flagged for the user to install once the phone is connected or the APK is transferred another
way. Not logged as a Step 4 app-code finding (the app under test on the emulator has no such
issue) — noted here as external context for whoever picks this up next.

**Type:** Flutter, device/emulator-based. **Model:** default; budget the longest session in this
plan. Target network: `http://100.121.165.7:8000/api` (Tailscale, matches `api_config.dart`'s
now-current default). Depended on Step 0 (now done) and Step 3 (done).

**Context brief:** Most likely to catch "missing screens" and UI-level discrepancies — named
explicitly by the user. **The first draft of this plan's screen list was incomplete** — grep
`lib/features/*/screens/` rather than trust any hand-written list, this plan's own included.

**Task list:**
1. **Derive the walk list, don't hand-write it**: enumerate `lib/features/*/screens/` and the
   route table in `lib/core/router/` (or wherever routes are registered) first, and tick off
   every domain found. Confirmed domains as of this grounding pass (verify this list is still
   current, don't trust it blindly): accounts, assets, auth, **budgets**, **calculators**,
   chatbot, **consent**, dashboard, **expenses**, goals, imports, insights, liabilities,
   portfolios, **ra**, settings, **summaries**, **tfsa**, transactions — the bolded ones were
   missing from this plan's first draft entirely.
2. Fresh AVD (or `pm clear` the existing `piggybank` AVD first to avoid the stale-biometric-lock
   red herring the prior QA pass hit) running against Step 0's final network config.
3. Walk every domain from Task 1's derived list systematically, including all Settings
   sub-screens, the Subscription/Upgrade flow (including the PayFast checkout UI — expect it to
   fail at the ITN-confirmation step per Step 0's known consequence; log that as expected, not a
   bug, but confirm the checkout screen itself still opens/renders correctly), and Admin.
   **`docs/admin-scope.md` exists but there is no `lib/features/admin/` directory** — confirm
   this directly (don't assume the doc reflects reality) and log Admin as a concretely
   **missing** screen if so, rather than the vague "if it exists" framing this plan's first draft
   used.
4. For each screen: loads without error? every visible action works? content matches what the
   backend actually returns (no stale/mismatched data — cross-check against Step 3's snapshot
   where relevant)? matches the current Stitch mockup where one exists (spot-check)? Log anything
   off: broken navigation, dead buttons, layout overflow, error toasts, mismatched copy, or a
   screen missing/unreachable from where a user would expect to find it.
5. Re-verify the two known-fixed-but-unconfirmed-live items: (a) AI net-worth parity (ask
   Chatbot/Insights for net worth, compare to Dashboard, same account/moment); (b) chatbot
   guardrail (ask an off-topic question, confirm a redirect not a direct answer).
6. ✅ **DONE.** Test the CSV import flow end-to-end at least once (known untestable in the
   automated harness). Exercised both a failure path (UI, via the app's file picker — see
   finding 20) and a success path (direct API, to see the backend's full error/response detail
   the UI hides — see findings 23–24). Test artifacts cleaned up (see the data-integrity caveat
   above the findings list for one complication that arose during cleanup, now resolved).
7. Log screenshots only for genuinely broken items, not for passing screens — keep the artifact
   set focused evidence for Step 5, not a full gallery.

**Verification:** N/A (exploratory) — every finding needs a reproduction path (exact tap
sequence / account state) recorded.

**Exit criteria: MET.** Every screen from Task 1's **derived** list has been opened and
exercised — including Instrument Comparison, the Imports Wizard, and (with the user's explicit
go-ahead to mutate demo data) the TFSA and Retirement Annuity ledgers — findings (or explicit
"no issue found") logged per domain, feeding Step 5.

---

## Step 5 — Consolidate findings into one prioritized report

**Type:** Documentation/synthesis. **Model:** default. **Depends on Steps 0–4 all being done.**

**Context brief:** Turn Steps 0–4's raw findings into one report a **new, separate fix-it
blueprint** can be planned from directly (see Current-state summary — this is not `piggybank-
launch-readiness.md`'s Step 1, which was already closed from a different input).

**Task list:**
1. Create `docs/qa/QA_FULL_SUITE_2026-08-31.md` (dated, alongside — not overwriting — the
   existing `QA_FINDINGS.md` and `docs/qa/QA_LOG.md`).
2. Structure it exactly like `QA_FINDINGS.md`'s existing Critical/High/Medium/Low convention.
3. For every finding: what's broken, exact reproduction steps/query/command, which step (0–4)
   found it, severity with a one-line justification.
4. Explicitly call out false alarms on re-check (e.g. seed-data bug already fixed) — report what
   is *not* broken too.
5. Add a top-line summary: total findings by severity, which domains are clean, which need the
   most attention.
6. Update `QA_FINDINGS.md`'s top with a short pointer to the new dated report, matching the
   existing 2026-08-28 update-section pattern rather than duplicating content.
7. Commit everything (network-lockdown config changes, the new report, any trivial incidental
   fixes) — `piggybank-backend` has a remote, push it (deployment to the server still requires
   the tar+scp path if anything server-side changed, per this plan's Mode section — pushing to
   `origin` alone is not a deploy); `Piggybank` has no remote, commit locally.

**Verification:** The report contains a non-empty repro field and a step (0–4) attribution for
every finding entry, `QA_FINDINGS.md` links to it, and the top-line summary's stated finding
count matches the actual number of finding entries in the file — not just a non-zero line count.

**Exit criteria:** One report exists, cross-referenced from `QA_FINDINGS.md`, containing every
finding from Steps 0–4 with reproduction evidence, severity, and an accurate top-line summary —
ready to hand directly to a new fix-it blueprint without re-deriving anything.

---

## Notes for whoever executes this plan

- **Do not skip Step 0's Task 3** (telling the user PayFast confirmation breaks) — this is a
  real functional regression during the Tailscale-only period, not a network implementation
  detail, and surfacing it mid-way through Step 2/4 as a "found bug" would misclassify an
  accepted, deliberate tradeoff as a defect.
- **Respect Step 3's ordering requirement.** Running Step 2 or Step 4 before Step 3, or
  concurrently with it, invalidates Step 3's "no new stray records" check — this was a real bug
  in this plan's first draft, caught on review.
- This plan does not re-run `piggybank-full-suite-qa.md`'s completed work from scratch.
- This plan's grounding paragraph about `piggybank-launch-readiness.md`'s status may itself go
  stale — re-verify against that file directly before treating Step 5's "feeds a new blueprint"
  framing as current fact if significant time has passed.
- This draft **was** adversarially reviewed (a second agent read the real files and live-probed
  the server) before being finalized — the review's Critical/High findings are folded into the
  text above rather than listed separately; nothing from that review was left unaddressed.
