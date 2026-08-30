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

1. **The app talks to the backend over plain HTTP by default, not HTTPS — contradicts the
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

1. **No password-reset / account-recovery flow exists at all.** Grepped
   `piggybank-backend/backend/app/` for `password.?reset|forgot.?password|reset_password` (case
   insensitive) — zero matches. `auth/router.py` has `register`, `login`, `refresh`, `logout`,
   `me`, PIN set/verify/remove — no "forgot password" endpoint, no email-based reset token flow.
   A user who forgets their password today has no way back into their account short of a manual
   DB intervention. This is a product-completeness gap as much as a security one (its *absence*
   is arguably lower security risk than a badly-implemented reset flow, but it's a real launch
   blocker for a consumer app) — flagged High because it blocks real users, not because it's an
   active vulnerability.

2. **No user-initiated data export or self-service account deletion exists — POPIA
   access/erasure rights have no implementation path, contradicting the compliance doc's own
   checklist.** `docs/compliance-foundation.md:59-63` ("Access And Correction Rights": users
   must be able to access their own data; "deletion or restriction workflows where legally
   appropriate") and its build-time checklist item 8 ("How will we delete or retain it?") are
   unimplemented. `auth/router.py` has no `DELETE /me` or `GET /me/export` endpoint. Per
   `piggybank-backend/CLAUDE.md`'s delete-policy summary, user hard-delete exists only as an
   "ops-only" capability (presumably a DB-level or admin-only action, not exposed to the user) —
   this satisfies a business's ability to delete data on request, but not a user's own
   self-service right to trigger it, which is what POPIA access/erasure rights are about.
   Consent-versioning itself (`require_current_consents`) is correctly implemented and out of
   scope for this finding.

3. **Refresh-token rotation exists, but there is no reuse-detection response.**
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

## Summary

| Severity | Count | Resolved |
|---|---|---|
| Critical | 1 | 0 |
| High | 4 | 1 (dependency CVEs) |
| Medium | 2 | 1 (`/ai/web-search` auth, reclassified from Medium) |
| Low | 6 | 0 |

**Step 1's remediation scope should prioritize, in order:** (1) the Critical HTTP-vs-HTTPS
transport gap — this needs an explicit decision (fix the routing so Caddy is actually in the
path, or consciously document "Tailscale IS the transport security" as the accepted model), (2)
password-reset flow (High #1) since it's a real launch blocker independent of any vulnerability,
(3) resolve the `/ai/web-search` auth question (Medium #2) since it's cheap to check and could
reclassify to High, (4) the refresh-token reuse-detection gap (High #3) and release-build
obfuscation (Medium #1) as concrete, scoped fixes, (5) POPIA export/erasure self-service (High
#2) as a larger feature that may deserve its own scoping conversation similar to Admin/Payments.
