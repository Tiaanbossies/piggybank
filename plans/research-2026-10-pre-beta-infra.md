# Research: pre-beta infrastructure (Piggybank)

Written 2026-10-12. Research only: no code, no spend, no changes to the server or any
account. Feeds the Phase B "beta plumbing" of `next-goal-friends-family-beta.md`, which
is paused behind `cost-cutting-plan.md` (now shipped, app 1.0.8+9).

**Decision it feeds:** what must be true of reachability, install, capacity, data safety,
operations and POPIA before 3-5 testers use Piggybank without Tiaan's help.

Rand figures assume roughly R18 per US$ (not verified; check the day you buy anything).

## Corrections and answers (added later on 2026-10-12)

Read these first; they supersede the text below where they differ.

| Topic | Correction |
|---|---|
| Backups (Q4) | The statement that nothing in the repo prevents total loss was too strong. `piggybank-backend/scripts/backup.sh` has existed since the initial commit (daily `pg_dump | gzip`, 7-day local retention) but was undocumented, local-only and never restore-tested. Backend PRs add weekly copies, encrypted off-host copy and a restore check |
| Bind address (Q1) | Compose defaults `BACKEND_BIND` to `0.0.0.0`, but `.env.docker.example` sets the tailnet IP. Funnel proxies to `127.0.0.1:8000`, so cutover needs `127.0.0.1`, and only after the HTTPS app build is installed |
| Public hostname (Q1) | Funnel publishes the **same** MagicDNS name the app already uses, on 443. No new domain needed for wave 1 |
| `/docs` exposure (Q1) | `backend/app/main.py` does not disable FastAPI's `/docs`, `/redoc`, `/openapi.json`; they become public with Funnel. Decide before cutover |
| Anthropic (Q3, Q6, Q7) | It does **not** normalise CSV categories. It receives the whole receipt image or PDF from `POST /imports/ocr`, and only when `OLLAMA_BASE_URL` is empty (compose defaults it to the local Ollama). No CSV text is sent |
| Crash reporting (Q5) | Confirmed none in the app (`pubspec.yaml`). Item 10 stays deferred |
| Cleartext (Q1) | `network_security_config.xml` permits cleartext only for `100.121.165.7` and `10.0.2.2`, not the MagicDNS name |

Tiaan's answers to the confirm list:

| Question | Answer |
|---|---|
| Host at home or hosted? | Home |
| CGNAT? | Unsure, thinks not. Funnel works either way |
| `fynboscreative.co.za` on Cloudflare DNS? | Unsure. Cloudflare Tunnel is not usable until known; not needed for Funnel |
| Play developer account? | None. A new personal account means the 12 testers / 14 days rule applies before production (internal testing is unaffected); an organisation account may be exempt but needs business registration and a D-U-N-S number: verify |
| `TAVILY_API_KEY` set in prod? | Unsure: check on the server |
| Information Officer registered? | No |
| Crash SDK in the app? | No |
| What does Anthropic receive? | Answered above |

## What the repos already say (read, not guessed)

| Fact | Source |
|---|---|
| App talks to the backend at `http://100.121.165.7:8000/api` over plain HTTP. `100.x` is a Tailscale address, so a tester outside the tailnet cannot reach it | `piggybank-backend/docs/runbook.md`, `Caddyfile` |
| `{$DOMAIN}`'s public DNS points to an unrelated server, so Caddy can never obtain a real certificate for it. Only plain-HTTP `/downloads` is actually served | `Caddyfile` comments |
| The host looks like a home or office PC on a tailnet (`tiaanbossies-h81m-ds2.tail886b94.ts.net`), not a hosted VPS. This is an inference from the hostname | `Caddyfile` |
| Backend publishes `0.0.0.0:8000` by default (`BACKEND_BIND`) | `docker-compose.yml` |
| One Postgres volume (`postgres_data`); no backup service, no cron, no dump step in compose or runbook | `docker-compose.yml`, `runbook.md` |
| Ollama is stringmonitor's GPU container (GTX1650, 4 GB), reached over the external `stringmonitor-db_default` network | `docker-compose.yml`, `CLAUDE.md` |
| Deploy job SSHes to `secrets.SSH_HOST` from a GitHub runner. A runner cannot reach a Tailscale-only host, which explains the "missing server host" failure | `.github/workflows/deploy.yml` |
| App manifest declares only `CAMERA`, `INTERNET`, `USE_BIOMETRIC` plus a `NotificationListenerService`. **No `READ_SMS`** | `Piggybank/android/app/src/main/AndroidManifest.xml` |
| `docs/compliance-foundation.md` section 9 lists individualised financial advice as a legal-review trigger; section 7 requires documenting where data and backups live | `compliance-foundation.md` |

## Q1. Reachability: how do testers reach the API with TLS?

| Option | Cost | Needs | Fit |
|---|---|---|---|
| **Tailscale Funnel** on the existing host | R0 | Funnel enabled in the tailnet; the host keeps its `*.ts.net` name and gets a valid cert. Public listener must be 443, 8443 or 10000. Tailscale documents "non-configurable bandwidth limits" and does not publish the number | Fastest. No domain, no router, works behind CGNAT. Fine for a small JSON API; do not push APK downloads through it |
| **Cloudflare Tunnel** | R0 (+ domain if none) | A domain whose DNS is on Cloudflare; `cloudflared` on the host. No inbound ports, works behind CGNAT | Durable choice. Needs a hostname such as `api.<domain>`; `fynboscreative.co.za` only works if its DNS can move to Cloudflare |
| **Caddy + public DNS + router port-forward** | R0 | Public (non-CGNAT) IP, 80/443 forwarded, a hostname pointing at it | Compose already has Caddy, but exposes a home IP and depends on the ISP. Weakest |

**Recommendation:** Tailscale Funnel for wave 1, with the backend bound to `127.0.0.1`
behind it; plan Cloudflare Tunnel once a hostname is decided. Either way the app needs a
build with a new `API_BASE_URL` (`api_config.dart`), so this is a release item, not just
a server item. Existing slowapi limits stay on, because the endpoint becomes public.
**Monthly cost: R0.**

Sources: [Tailscale Funnel docs](https://tailscale.com/docs/features/tailscale-funnel),
[Funnel limits summary](https://www.ssdnodes.com/learn/tailscale-funnel-limits-and-ports),
[Cloudflare Tunnel docs](https://developers.cloudflare.com/tunnel/),
[Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https). Retrieved 2026-10-12.

## Q2. Install path: Play internal testing or a public APK link?

- Google Play **internal testing** reaches up to 100 named testers with no review step.
  The Play developer account is a one-off US$25 (about R450).
- The "12 testers for 14 consecutive days" closed-test rule applies only to getting
  **production** access, and only to personal accounts created after 2023-11-13. It does
  not block an internal test. It will matter before any public Play release, and Google
  assesses how active the testers were, not just the count.
- **The SMS/Call Log restriction does not apply as built:** the app has no `READ_SMS`; it
  reads bank alerts through a notification listener. The notification-access side is
  still a sensitive capability that Play reviews for a production listing. Google's
  "Permissions and APIs that Access Sensitive Information" policy has an update
  **effective 2027-01-27**; read it before applying for production.
- **Android 15 redacts notifications in which it detects a one-time code** from
  untrusted listeners. Bank transaction alerts are normally not OTPs, but a tester on
  Android 15+ whose bank mixes codes into the alert text will show missing captures.
  Test on one Android 15 device before invites.

**Recommendation:** Play internal testing for wave 1 (updates without sideload warnings,
no tester-side "unknown sources"). Keep the `/downloads` APK as Tiaan's own fallback.
**Cost: about R450 once.** Tiaan to confirm: does a Play developer account already exist,
and when was it created?

Sources: [Play: testing requirements for new personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en),
[Play: sensitive permissions policy](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en),
[Android Authority on Android 15 sensitive notifications](https://www.androidauthority.com/android-15-sensitive-notifications-3416414).
Retrieved 2026-10-12. Internal-testing cap and fee come from secondary sources
([PrimeTestLab](https://primetestlab.com/blog/paid-25-google-play-now-what)); confirm in
Play Console before relying on them.

## Q3. Capacity: can the shared 4 GB GPU serve 5 testers?

- Ollama defaults: `OLLAMA_NUM_PARALLEL` = 1 (requests are handled one at a time),
  `OLLAMA_MAX_QUEUE` = 512, default context 4,096 tokens. Memory grows with
  parallel x context length.
- So five testers are served in sequence, behind whatever stringmonitor is running. The
  backend's `OLLAMA_TIMEOUT_SECONDS` is 120. The risk is a slow reply at a busy moment,
  not a crash. Nobody has measured latency under load yet.
- Fallback cost, from Anthropic's published pricing: **Claude Haiku 5.5 is US$0.10 per
  million input tokens and US$0.50 per million output tokens.** A chat of about 3,000 in
  and 500 out is roughly US$0.0006, so 1,000 chats is about US$0.55 (under R10).
  Cost is not the barrier; the barrier is the consent text (policy facts and premiums
  would go to Anthropic), as `cost-cutting-plan.md` D5 already notes.

**Recommendation:** keep Ollama for wave 1. Before invites, run a timed 5-concurrent-chat
test while stringmonitor is busy and log p50 and p95; if p95 is over about 30 seconds,
switch policy checks to Haiku and update the consent document in the same change.
**Cost now: R0; fallback under R10 per 1,000 chats.**

Sources: [Ollama FAQ](https://docs.ollama.com/faq),
[Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing).
Retrieved 2026-10-12.

## Q4. Data safety: backups and restore

Today a lost or corrupted `postgres_data` volume is a total loss of every user's
transactions, and nothing in the repo prevents it. `docker compose down -v` deletes it
(runbook warns).

**Recommendation (before any tester has data):**
1. Nightly `pg_dump` from the `db` container via host cron, compressed, 14 daily +
   8 weekly retained.
2. Copy off the host each night, encrypted (the data is "Confidential" in
   `compliance-foundation.md` section 6). Candidates: the Fynbos VPS, or any
   object store; where it lands must be written down (section 7).
3. A restore into a scratch database, done once, with the date recorded in the runbook.
4. Back up `.env.docker` separately (it is git-ignored and holds the JWT and
   encryption keys; losing `GMAIL_TOKEN_ENCRYPTION_KEY` makes stored tokens unreadable).

**Cost: R0** if the off-host copy goes to the existing VPS.

## Q5. Deploy and uptime

- **Deploy:** the GitHub job fails by design: a hosted runner has no route to a
  `100.x` address. Options: (a) keep the manual `git pull` deploy documented in the
  runbook and stop the job from failing red on every merge (gate it on a repo variable);
  (b) join the runner to the tailnet with the Tailscale GitHub Action and an ephemeral
  auth key. For one developer and a few merges a week, **(a)**. Revisit if Cloudflare
  Tunnel adds SSH access.
- **Uptime:** needs a public URL, which Q1 provides. UptimeRobot's free plan is 50
  monitors at 5-minute checks. Self-hosted Uptime Kuma would die with the same host it
  watches, so it is the wrong tool here. **Cost: R0.**
- **Crash reporting (Flutter app):** Firebase Crashlytics is free with no event cap and
  90-day retention; Sentry's free Developer plan is 5,000 errors a month, one user,
  30-day retention. Both send stack traces off-device, so each is a POPIA operator
  (Q6). Lean **Sentry** for control over scrubbing (strip amounts, merchant names and
  message text before send). Not verified against the Piggybank code: whether any
  crash SDK is already present.

Sources: [UptimeRobot comparison](https://uptimerobot.com/knowledge-hub/comparisons-and-alternatives/11-best-uptime-monitoring-tools-compared/),
[Sentry pricing](https://sentry.io/pricing/),
[mobile error tracking comparison](https://www.drizz.dev/post/cheapest-mobile-error-tracking-tools).
Retrieved 2026-10-12. Vendor pricing pages change; recheck at signup.

## Q6. POPIA readiness once users are not Tiaan

Not legal advice; the items below are the gaps to put in front of a South African
privacy practitioner.

| Duty | What it means here | Status |
|---|---|---|
| **Operator contracts (s21)** | A written contract with every operator that touches personal information, covering security measures, breach notice and return/deletion. The Regulator has enforced this on its own (Dis-Chem notice) | Likely none today. Candidates: Anthropic (CSV import), Sentry/Crashlytics, uptime vendor, off-host backup store. Tavily receives only generic whitelisted queries, so it is probably not an operator of personal information; keep the query-safety test as the evidence |
| **Breach notification (s22)** | Responsible party notifies the Regulator and affected users "as soon as reasonably possible". Some sources cite a 72-hour guideline; I could not confirm it from the Regulator | A one-page breach runbook does not exist |
| **Cross-border (s72)** | Transfers need a lawful ground (usually a contract giving equivalent protection) | Anthropic and any US-hosted crash or backup vendor. `compliance-foundation.md` section 7 already requires this reviewed before launch |
| **Information Officer** | Registered with the Regulator before acting; done on its eServices portal. The head of a private body is the default officer | Not recorded anywhere. Tiaan to confirm whether Fynbos Creative has registered |
| **Consent and privacy policy** | Must name every operator and what leaves the device | Update with whatever Q5 picks |
| **Financial regulation trigger** | Section 9: individualised advice triggers a legal review. Penny's policy research is built as facts, sourced ranges and broker questions; the cost-cutting plan already flagged re-reading section 9 before other users | Open. Decide before invites |

Sources: [Information Regulator](https://inforegulator.org.za/popia/),
[Fasken on operator contracts](https://fasken.com/en/knowledge/2023/09/beware-of-the-operator-contract-a-necessity-for-popia-compliance),
[Dis-Chem enforcement notice](https://inforegulator.org.za/wp-content/uploads/2020/07/DIS-CHEM-ENFORCEMENT-NOTICE.pdf),
[s72 overview (Dentons)](https://www.dentons.com/en/insights/articles/2022/october/13/cross-border-data-transfers-under-the-protection-of-personal-information-act-4-of-2013).
Retrieved 2026-10-12.

## Q7. Third-party spend ceiling for 5 testers

| Item | Recurring | One-off |
|---|---|---|
| Public reachability (Funnel or Cloudflare Tunnel) | R0 | Domain only if none (a few hundred rand a year) |
| Google Play developer account | R0 | about R450 |
| Tavily: free tier is 1,000 credits a month; the app budget counter caps at 800. Estimate 5 users x ~10 checks x 3 queries is about 150, less with the cache | R0 | |
| Anthropic Haiku (CSV import, optional Penny fallback) | cents to under R10 | |
| Uptime monitor, crash reporting (free tiers) | R0 | |
| Backups off-host (existing VPS) | R0 | |
| **Total** | **about R0 a month** | **about R450** |

Tavily numbers: [Tavily pricing](https://www.tavily.com/pricing). Retrieved 2026-10-12.

## Pre-beta checklist (ordered)

1. [ ] Nightly encrypted off-host backup + one tested restore (Q4). **Blocks invites.**
2. [ ] Decide the public hostname; enable Funnel or Cloudflare Tunnel; bind backend to
       `127.0.0.1` (Q1).
3. [ ] Ship an app build with the new HTTPS `API_BASE_URL`; install it on Tiaan's phone
       first and run the 14-day streak on it.
4. [ ] Put a monitor on `/api/health` (Q5).
5. [ ] Timed 5-concurrent-chat test against shared Ollama; decide Ollama vs Haiku (Q3).
6. [ ] Play developer account + internal test track; add testers (Q2).
7. [ ] Test notification capture on an Android 15 device (Q2).
8. [ ] Write operator list, update consent/privacy text, one-page breach runbook;
       confirm Information Officer registration (Q6).
9. [ ] Re-read compliance-foundation section 9 and decide whether a legal review is
       needed before non-family users (Q6).
10. [ ] Crash reporting with scrubbing, or an explicit decision to defer (Q5).

**Go / no-go for the invite date:** go only if items 1, 2, 3, 4 and 8 are done and 5 shows
an acceptable p95. Items 6, 7, 9 and 10 can land in the first invite week.

## Tiaan to confirm (I did not touch the server or any account)

- Is the host at home or hosted, and does the ISP give a public IP or CGNAT?
- Is `fynboscreative.co.za` (or another domain) on Cloudflare DNS?
- Does a Play developer account exist, and when was it created?
- Is `TAVILY_API_KEY` set in production? (Still open from the cost-cutting plan.)
- Has an Information Officer been registered for Fynbos Creative?
- Does the Piggybank app already include a crash-reporting SDK?
- What exactly does the Anthropic CSV import send (descriptions only, or amounts too)?

## Not done / limits

No load test, no server inspection, no Play Console check; Play's internal-testing cap
and fee are from secondary sources. The POPIA table is a gap list for a practitioner,
not advice.
