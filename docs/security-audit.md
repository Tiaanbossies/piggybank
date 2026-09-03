# Piggybank Security Audit — 2026-08-30

Step 0 of `plans/piggybank-launch-readiness.md`. First formal security audit of the app.
Every finding below is grounded in a specific file/line or a reproduced command output — none
are recited from a generic checklist. Structure mirrors `QA_FINDINGS.md`'s existing
Critical/High/Medium/Low convention.

**Scope:** `piggybank-backend/backend/app/{security,config,main,limiter,auth}.py`, dependency
pins in `requirements.txt`, git history of both repos, Flutter token storage/release-build
config, transport security (Caddy/TLS), and `docs/compliance-foundation.md` vs. actual
implementation.

**Not verified live this session:** the backend host `100.121.165.7` was unreachable from this
machine (`ssh ... Connection timed out`, port 22) — same carried-over blocker as prior sessions
(no Tailscale connection here). Findings below that would benefit from a live check are marked
**[needs live verification]**.

---

## Critical

1. **DEFERRED 2026-08-30, user-acknowledged — accepting Tailscale-as-transport-security rather
   than routing through Caddy.** Routing through Caddy for a real Let's Encrypt cert requires a
   public DNS hostname pointed at the server's real public IP; the user confirmed no domain is
   available right now (`api_config.dart`'s Tailscale-IP default and `docker-compose.yml`'s
   `DOMAIN` bare-IP default are therefore staying as-is). The mitigating factor below still
   applies — traffic never leaves the WireGuard-encrypted tailnet — and this is being tracked as
   a conscious deferral, not a silent gap: revisit once a domain exists, per the recommendation
   below.
   **The app talks to the backend over plain HTTP by default, not HTTPS — contradicts the
   project's own compliance doc.** `Piggybank/lib/core/api/api_config.dart:9` hardcodes
   `defaultValue: 'http://100.121.165.7:8000/api'`. `piggybank-backend/docker-compose.yml:30-31`
   publishes the `backend` service's port 8000 directly on the host
   (`"${BACKEND_PORT:-8000}:8000"`), so requests to that URL go straight to the FastAPI
   container, **bypassing Caddy entirely** — Caddy (which does auto-HTTPS) is bound to
   `8081`/`443` (`docker-compose.yml:105-108`) and is not in the path the app actually uses.
   `docs/compliance-foundation.md:67` states as a compliance requirement: "All production
   traffic should use HTTPS." This is currently violated by the shipped app's default
   configuration.
   - **Mitigating factor:** `100.121.165.7` is a Tailscale address, so traffic stays inside the
     WireGuard-encrypted tailnet rather than crossing the public internet in the clear — this is
     not equivalent to serving a public API over plaintext HTTP. But it still means: any other
     device/user on the same tailnet (if Tailscale ACLs are ever loosened) can read login
     credentials, JWTs, and financial data in transit; there is no protection if a tailnet peer
     is compromised; and Caddy's TLS setup is effectively dead code for real app traffic today.
   - **[needs live verification]:** could not confirm what `DOMAIN` is actually set to in the
     server's `.env.docker`, or whether Caddy is even reachable/serving a valid cert, because the
     host was unreachable this session. `docker-compose.yml:110`'s own default
     (`DOMAIN: ${DOMAIN:-100.121.165.7}`) is a bare IP, and Caddy's automatic HTTPS (ACME) cannot
     issue a real certificate for a bare IP — if `DOMAIN` was never overridden to a real hostname,
     Caddy has nothing valid to serve regardless.
   - **Recommendation:** either terminate TLS on the same port the app actually calls (put Caddy
     in front of port 8000, or repoint the app at Caddy's port and remove the direct :8000
     publish), or explicitly accept and document the "Tailscale-only, HTTP-over-VPN is our
     transport security model" decision — right now the app config and the compliance doc
     disagree with each other, and that gap should be closed one way or the other before this is
     called production-ready.

---

## High

1. **RESOLVED 2026-08-30 — self-service password-reset flow added.** Backend:
   `POST /auth/password-reset/request` (always 204, no email enumeration; generates an 8-digit
   code via `security.generate_reset_code()`, stores its SHA-256 hash in a new
   `password_reset_tokens` table with a 30-minute expiry, delivers it via a new stdlib-`smtplib`
   `services/email_client.py`) and `POST /auth/password-reset/confirm` (validates the code,
   updates `password_hash`, revokes every existing refresh token for the user so a reset also
   forces re-login everywhere). Flutter: new `ForgotPasswordScreen` and `ResetPasswordScreen`,
   linked from a "Forgot password?" link on the login screen. **Caveat:** SMTP is not yet
   configured anywhere (`SMTP_HOST` defaults empty, so sends are only logged) — the flow is fully
   built and tested, but won't actually deliver an email until real SMTP credentials are set in
   `.env.docker`. **Verified:** 9 new backend tests (happy path, wrong/reused/expired code,
   rate limiting, revokes-all-sessions) plus 6 new Flutter tests (API request-shape + error
   handling); full backend suite 1034/1035 passing (1 pre-existing unrelated failure), full
   Flutter suite 411/412 passing (1 pre-existing unrelated failure).
   **Originally:** No password-reset / account-recovery flow existed at all. Grepped
   `piggybank-backend/backend/app/` for `password.?reset|forgot.?password|reset_password` (case
   insensitive) — zero matches. `auth/router.py` has `register`, `login`, `refresh`, `logout`,
   `me`, PIN set/verify/remove — no "forgot password" endpoint, no email-based reset token flow.
   A user who forgets their password today has no way back into their account short of a manual
   DB intervention. This is a product-completeness gap as much as a security one (its *absence*
   is arguably lower security risk than a badly-implemented reset flow, but it's a real launch
   blocker for a consumer app) — flagged High because it blocks real users, not because it's an
   active vulnerability.

2. **RESOLVED 2026-08-30 — self-service data export and account deletion added.**
   `GET /auth/me/export` returns everything the user owns (profile, accounts, transactions,
   assets, liabilities, budgets, goals, portfolios+holdings, imports, category rules, TFSA/RA
   contributions, net-worth snapshots, consents, subscription) as JSON, via a new
   `auth/data_export.py` that reflects each model's columns and redacts hash/secret fields by
   name. `DELETE /auth/me` (requires current-password re-auth) hard-deletes the user, relying on
   the cascades already documented in `docs/delete-policy.md`. Flutter: new "Export my data" /
   "Delete my account" rows on the Security screen — export shows pretty-printed JSON with a
   copy-to-clipboard action (no new `share_plus`/`path_provider` dependency added for a
   rarely-used flow); delete requires a confirmation dialog then the current password. **Verified:**
   4 new backend tests (export includes owned data + excludes secrets, requires auth, delete
   removes the row and rejects a wrong password) plus the same full-suite pass counts as finding
   #1 above.
   **Originally:** No user-initiated data export or self-service account deletion existed — POPIA
   access/erasure rights had no implementation path, contradicting the compliance doc's own
   checklist. `docs/compliance-foundation.md:59-63` ("Access And Correction Rights": users
   must be able to access their own data; "deletion or restriction workflows where legally
   appropriate") and its build-time checklist item 8 ("How will we delete or retain it?") are
   unimplemented. `auth/router.py` has no `DELETE /me` or `GET /me/export` endpoint. Per
   `piggybank-backend/CLAUDE.md`'s delete-policy summary, user hard-delete exists only as an
   "ops-only" capability (presumably a DB-level or admin-only action, not exposed to the user) —
   this satisfies a business's ability to delete data on request, but not a user's own
   self-service right to trigger it, which is what POPIA access/erasure rights are about.
   Consent-versioning itself (`require_current_consents`) is correctly implemented and out of
   scope for this finding.

3. **RESOLVED 2026-08-30 — refresh-token reuse detection added.** A new `family_id` column on
   `RefreshToken` threads a login's token lineage through every rotation (same family_id carried
   forward on each rotate, fresh one per login). `/auth/refresh` now branches on `row.revoked`
   specifically: presenting an already-revoked token revokes every row sharing its `family_id`
   (including the token the legitimate rotation just produced) before returning 401 — forcing a
   real re-login rather than trusting either party. Plain expiry (never revoked) does not trigger
   this — only actual reuse does. Also applied proactively on password reset (finding #1): a
   reset revokes every existing refresh token for the user. **Verified:** 3 new backend tests
   (reuse kills the whole family including the legitimately-rotated token, normal rotation keeps
   the same family_id, plain expiry does not trigger a family-wide kill) plus a new Alembic
   migration (`d6e7f8a9b0c1`) backfilling `family_id = id` for every pre-existing row.
   **Originally:** Refresh-token rotation existed, but there was no reuse-detection response.
   `auth/router.py:171-179`'s `/auth/refresh` correctly rotates on every use (marks the old
   `RefreshToken` row `revoked = True`, issues a new pair) — this is good practice, better than
   many apps do. However, if a refresh token is ever stolen and used by an attacker, the
   *legitimate* user's next refresh attempt with the same (now-already-revoked) token just gets a
   generic 401 (`row.revoked` check at line 164 folds into the same `_NOT_AUTHENTICATED` branch as
   "not found"/"expired") — there is no signal distinguishing "this token was already used by
   someone else" from "this token is simply old/expired," and no automatic response (e.g.
   revoking the entire token family, forcing re-login, alerting the user) to a detected reuse.
   This is the standard "refresh token reuse detection" pattern from OAuth security best
   practice, and it's the one piece missing from an otherwise well-built rotation scheme.

4. **Backend dependency CVE scan — completed 2026-08-30, 27 known vulnerabilities found across
   8 packages.** Update from the original finding above (venv now populated, `pip-audit`
   installed and run against `requirements.txt`; `uvloop` excluded from the scan copy since it
   doesn't build on this Windows dev machine and isn't itself a flagged package). Results:
   - **`pyjwt==2.12.1`** — 8 distinct advisory IDs (PYSEC-2026-175/176/177/178/179, several
     duplicated across dependency paths), fix in `2.13.0`. **Highest-priority item on this
     list** — this is the library issuing/verifying every access and refresh token in the app.
   - **`starlette==1.0.0`** — 5 distinct advisories (PYSEC-2026-161/248/249/2280/2281), fixes
     range up to `1.3.1`. FastAPI's transport layer — also high-priority.
   - **`python-multipart==0.0.27`** — 3 advisories, fixes in `0.0.30`/`0.0.31`.
   - **`urllib3==2.6.3`** — 2 advisories, fix `2.7.0`.
   - **`soupsieve==2.8.3`** — 2 advisories, fix `2.8.4` (pulled in via `yfinance`'s HTML
     scraping path, not directly used by app code — lower priority).
   - **`idna==3.13`** — 1 advisory, fix `3.15`.
   - **`mako==1.3.11`** — 1 advisory, fix `1.3.12` (alembic's templating dependency, not
     runtime-reachable — lower priority).
   - **`pydantic-settings==2.14.0`** — 1 advisory (GHSA-4xgf-cpjx-pc3j), fix `2.14.2`.
   **RESOLVED 2026-08-30** — all 8 packages bumped in one `pip-compile --upgrade-package` pass
   (`pyjwt` 2.13.0, `starlette` 1.6.0, `python-multipart` 0.0.32, `urllib3` 2.7.0, `soupsieve`
   2.9.2, `idna` 3.19, `mako` 1.4.1, `pydantic-settings` 2.15.0). Re-running `pip-audit` against
   the recompiled `requirements.txt` returns **no known vulnerabilities**. Full backend suite still
   1020/1021 passing (same pre-existing unrelated `test_health.py` failure). Recompiling on this
   Windows dev machine also surfaced that `requirements-dev.txt` had silently drifted — missing
   `yfinance`/`anthropic`/`tavily-python`/`apscheduler` entirely despite its own header claiming
   "strict superset of runtime" — fixed by recompiling it constrained to `requirements.txt` (`-c`)
   so both lockfiles agree on every shared version. `uvloop`'s pin was manually restored in both
   files after each recompile, since pip-compile resolves per-platform and silently drops it when
   run on Windows (its own metadata excludes `win32`) — production is Linux and must keep it.

---

## Medium

1. **Android release build has no confirmed code obfuscation/shrinking.**
   `Piggybank/android/app/build.gradle.kts:50-54`'s `release` build type sets only
   `signingConfig` — no `isMinifyEnabled = true`, no `isShrinkResources = true`, no ProGuard/R8
   rules file reference. Flutter's own `--obfuscate --split-debug-info=<dir>` build flags (which
   obfuscate the *Dart* code, separate from R8/ProGuard which only covers the Kotlin/Java
   Android-embedding layer) were not found referenced in any build script, `Makefile`, or CI
   workflow in this repo — meaning `flutter build appbundle --release` (the exact command used
   for Step 9a's Play Store build) almost certainly ships without Dart obfuscation. For a
   financial app, decompiling the release APK/AAB would currently expose readable Dart symbol
   names and business logic more easily than necessary. Not Critical because the actual secrets
   (JWT signing, password hashing) live server-side, not in the client binary — but still worth
   closing before a real public Play Store release.

2. **RESOLVED 2026-08-30 — `/ai/web-search` had no auth dependency at all, confirming the worse
   of the two suspected outcomes.** `backend/app/routes/ai.py`'s `web_search_endpoint` took only
   `request: WebSearchRequest` — no `Depends(get_current_user)`, unlike every other `/ai`-prefixed
   route (`ai/routes.py`'s `context-preview`/`insights` both require it). This was a genuinely
   unauthenticated proxy to an external search API — cost-abuse and SSRF-adjacent surface, exactly
   the worse case flagged below. **Fix:** added `current_user: User = Depends(get_current_user)`,
   matching the existing pattern. It still bypasses `AI_FEATURES_ENABLED` (per
   `piggybank-backend/CLAUDE.md`'s documented gotcha — mounted directly on `app`, not gated like
   `chat_router`) — that part is an intentional exception, not fixed here, and should stay
   documented rather than "closed." **Verified:** new `tests/test_routes_ai.py` — 401 without a
   token, 200 with one; full backend suite still 1020/1021 passing (same pre-existing unrelated
   failure as before). Upgrades this finding from Medium to (resolved) High, since it was
   confirmed as the actual vulnerability, not the documented-exception case.

---

## Low

1. **JWT secret fail-fast guard is correct in code but unverified live.**
   `piggybank-backend/backend/app/config.py:59-66`'s `_require_strong_secret_in_production`
   validator correctly raises at settings-instantiation if `app_env == "production"` and
   `jwt_secret_key` still equals the literal default dev value — this is real, not just a
   comment. `docker-compose.yml:42` also requires `JWT_SECRET_KEY` to be set via
   `${JWT_SECRET_KEY:?...}` (fails the container start if unset). Both layers look correct by
   inspection. **[needs live verification]:** could not confirm the *actual* deployed
   `JWT_SECRET_KEY` is a real random secret and not accidentally left as the dev default with
   `app_env` misconfigured to something other than `"production"` (e.g. left at the default
   `"development"` value, which would silently skip the guard) — the host was unreachable this
   session.
2. **No raw/string-interpolated SQL found** — grepped both `execute(text(` and f-string-built
   SQL patterns across `backend/app/`, zero matches. SQL injection surface is effectively zero
   via the SQLAlchemy ORM, as expected. No action needed — recorded as a confirmed-clean check,
   not a gap.
3. **`pytest -m live` tests are safe to run without secrets.** `tests/test_yfinance_live.py`
   (the only file using the `live` marker) only calls public, unauthenticated yfinance ticker
   lookups (`_resolve_symbol`, `_fetch_last_prices`) — no API keys or credentials required to run
   it, and each test already wraps network calls in `try/except` + `pytest.skip` on failure. No
   action needed.
4. **Secrets hygiene: clean.** Grepped full git history (`git log --all -p`) of both
   `piggybank-backend` and `Piggybank` for AWS-style keys, `sk-`-prefixed API keys, and PEM
   private-key headers — zero hits. `.env`/`.env.*` are correctly gitignored in
   `piggybank-backend` (only `.env.*.example` placeholder files with dummy values ever
   committed); `android/.gitignore` correctly covers `key.properties`/`*.jks`/`*.keystore` in
   `Piggybank` (matches the keystore backup work already done in Step 9a of the production
   blueprint). No action needed.
5. **Refresh token persisted client-side correctly, access token memory-only, exactly as
   documented.** `Piggybank/lib/core/auth/secure_storage.dart` stores only the refresh token via
   `flutter_secure_storage` (Keychain/Keystore-backed); confirmed by reading the file directly —
   the access token is never written here, matching `piggybank-backend/CLAUDE.md`'s stated
   contract ("expects the client to hold [the access token] only in memory, never persistent
   storage"). No action needed.
6. **CORS/CSP posture is reasonable.** `main.py:47-53` restricts CORS to `settings.cors_origins`
   (no wildcard `*`), restricted method/header allowlists. CSP is deliberately not set in FastAPI
   middleware, left to Caddy per `CLAUDE.md`'s explicit note (avoids the double-CSP-conflict
   footgun) — consistent with the Critical finding above, this only matters once Caddy is
   actually in the request path for real traffic. `X-Frame-Options: DENY`,
   `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` are all
   set (`main.py:16-22`). No action needed beyond resolving the Critical finding above.

---

## Not fully investigated this session (follow-ups)

- **`backend/app/routes/ai.py`'s auth requirement** — see Medium finding 2. Read this file
  directly before Step 1 remediation planning.
- **Live verification of `DOMAIN`, Caddy cert validity, and actual deployed `JWT_SECRET_KEY`/
  `APP_ENV`** — blocked on backend host reachability this session (`ssh 100.121.165.7` timed
  out). Re-attempt once Tailscale is connected from whatever machine runs Step 1.
- **A real dependency CVE scan** (`pip-audit`/`safety` against a properly populated venv or in
  CI) — not completed, see High finding 4.
- **Certificate pinning on the Flutter client** — not investigated this session; worth deciding
  whether it's warranted given the Tailscale-only transport model, once the Critical finding
  above is resolved one way or the other (pinning a cert only matters if there's a real cert in
  the path to begin with).

---

## Live verification follow-up — 2026-09-03

The backend host (`100.121.165.7`) is reachable this session (direct SSH + HTTP both confirmed).
Closing out the "[needs live verification]" items above, plus one thing the original audit
couldn't have seen since the host was down that day.

- **Low #1 (JWT secret) — CONFIRMED GOOD.** `.env.docker`'s `JWT_SECRET_KEY` is overridden from
  the dev default (64 hex chars = 32 bytes, correct length for HS256) and `docker-compose.yml`
  hardcodes `APP_ENV: production` directly (not read from `.env.docker`), so the fail-fast guard
  is armed and passing. No action needed — this finding is now fully closed, not just
  "correct by inspection."

- **Critical #1 (HTTP-vs-HTTPS transport) — still open, and the original deferral reasoning is
  now stale.** The audit's deferral said "no domain is available right now." That's no longer
  true: `.env.docker`'s `DOMAIN=piggybank.fynboscreative.co.za`, and that hostname **does**
  resolve (to `102.214.9.185`). But Caddy has been failing to obtain a cert for it on every retry
  since at least two cycles ago (`docker compose logs caddy`, 6-hourly retry loop): both the
  `tls-alpn-01` and `http-01` ACME challenges fail with `102.214.9.185: remote error: tls:
  internal error` — meaning that IP either isn't routing inbound :80/:443 traffic to this Caddy
  container, or something in front of it (another Caddy/nginx instance, a firewall, a different
  physical box) is answering instead. **Separately, and worth fixing regardless of the DNS/routing
  issue:** Caddy's ACME client is pointed at `acme-staging-v02.api.letsencrypt.org` — Let's
  Encrypt's **staging** directory, which by design never issues browser-trusted certificates. Even
  if the routing problem were fixed today, this domain would still not get a real cert until the
  Caddyfile/compose config is switched to the production ACME directory. The app's actual live
  traffic still goes over plain HTTP to the Tailscale IP (`api_config.dart`'s default), so this
  doesn't change the current risk picture from the original mitigating-factor analysis — but the
  deferral's stated reason for accepting it ("no domain available") no longer matches reality, and
  should be re-confirmed with the user rather than left standing on outdated grounds.

- **New finding — PayFast is running on sandbox credentials in production.** `.env.docker` has
  zero `PAYFAST_*` entries (`grep -c '^PAYFAST_' .env.docker` → 0), and `docker-compose.yml`'s
  `backend` service environment block doesn't forward any `PAYFAST_*` vars even if they were set —
  confirming the gap flagged but not verified in the Step 1 status notes below. This means
  `config.py`'s hardcoded PayFast **sandbox** defaults (`payfast_sandbox: true`, test
  `merchant_id`/`merchant_key`, published PayFast test credentials) are silently active on the
  live server right now. Practical effect: every "Upgrade to Pro" checkout in production today
  goes through PayFast's sandbox — no real card is charged — while `subscriptions_router` grants
  real Pro-tier access on a successful sandbox ITN callback, same as it would for a real payment.
  This is a business-correctness gap, not just a security one: real users can currently get Pro
  access without PayFast ever processing real money, and once real credentials are wired in this
  same misconfiguration would do the opposite (fail to bill anyone, or charge against the wrong
  merchant account) if not deliberately fixed. **Requires a user decision, not a unilateral code
  fix** — same pattern as the original payment-gateway scoping gate: real PayFast merchant
  credentials (from `docs/payment-gateway-scope.md`'s "PayFast merchant account signup" step) need
  to actually exist before this can be closed, and `docker-compose.yml` needs the `PAYFAST_*`
  passthrough lines added (same fix already applied for `SMTP_*` in Step 1, just never mirrored
  for PayFast).

**User decisions, 2026-09-03 (both re-confirmed with the changed facts above):**
- **Critical #1 (HTTP transport) — deferral stands.** User re-confirmed plain HTTP over the
  Tailscale tunnel is acceptable for now despite the domain now existing; the Caddy
  routing/staging-ACME issue is not being fixed at this time. Revisit once public HTTPS is
  actually wanted.
- **PayFast sandbox — deferral confirmed, by design pre-launch.** No real users are being
  incorrectly charged since the app isn't live-marketed yet. Leave on sandbox credentials until
  ready to accept real payments and a real PayFast merchant account exists.

---

## Summary

| Severity | Count | Resolved |
|---|---|---|
| Critical | 1 | 0 (deferred 2026-08-30, user-acknowledged) |
| High | 4 | 4 |
| Medium | 2 | 1 (`/ai/web-search` auth, reclassified from Medium) |
| Low | 6 | 0 |

**Step 1 status (updated 2026-08-30): exit criteria met.** Every Critical/High finding is either
fixed or has a written, user-acknowledged deferral reason, matching
`plans/piggybank-launch-readiness.md`'s Step 1 exit criteria exactly:
- Critical #1 (HTTP-vs-HTTPS transport) — **deferred**, user confirmed no domain is available for
  a real Let's Encrypt cert; Tailscale-as-transport accepted as the model for now.
- High #1 (password-reset), #2 (POPIA export/deletion), #3 (refresh-token reuse detection), #4
  (dependency CVEs) — **all resolved**, see each finding above for what shipped and how it was
  verified.
- Medium #1 (Android release-build obfuscation) remains open — Medium severity, outside Step 1's
  fixed exit criteria (Critical/High only), can be picked up separately.
- Two real gaps surfaced *while implementing* Step 1, unrelated to any specific finding above but
  worth flagging: `docker-compose.yml`'s `backend` service never forwarded the PayFast env vars
  added last session (`PAYFAST_*`), so a production deploy would silently run on PayFast's
  sandbox test credentials instead of real ones — not fixed here (out of Step 1's scope, and not
  something this session introduced), but SMTP's own passthrough was added correctly this session
  so as not to repeat the mistake. Real SMTP credentials also still need to be set in
  `.env.docker` before password-reset emails actually deliver (currently only logged).
