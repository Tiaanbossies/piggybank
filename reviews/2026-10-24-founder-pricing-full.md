# Piggybank: founder and pricing review, update (full report)

**Date:** 2026-10-24 · **Author:** Claude for Tiaan · **Scope:** read-only review of product, pricing, beta plan, distribution and go-to-market, with fresh web research

**Builds on:** `reviews/2026-10-19-founder-pricing-full.md` · **Short version:** `reviews/2026-10-24-founder-pricing.md`

**How to read the numbers:** every outside figure has a link and was checked on 2026-10-24. Anything without a link is labelled **Estimate** with its arithmetic, or **Not found**. Where this report changes a 10-19 figure or recommendation, it says so in a "vs 10-19" note.

---

## 0. What changed since 2026-10-19

| Area | 2026-10-19 | Now (2026-10-24) | Source |
|---|---|---|---|
| App on `master` | 1.0.9+10 | **1.0.10+11** (#80), plus #79 (notification capture no longer fails silently) and docs/test PRs #81 to #84 | `git log origin/master` |
| Backend on `main` | `454b3c8` (#32) | `d35db82` (#35). New: #33 (Penny error messages, Funnel deploy fix), #34 and #35 (cleanup) | `git log origin/main` |
| Backend #32 deployed? | Not checked | **Yes.** The host runs `f3112be`, which contains #32's merge commit, and its `backend/` tree is identical to `main` | `piggybank-status` on fynbos-server; `git merge-base --is-ancestor`; `git diff` |
| Host health | Not checked | Backend, Caddy and Postgres containers up 3 days, backend healthy, `/api/health` returns `{"status":"ok","ai_features_enabled":true}` | `piggybank-status` |
| Pro gating | Pro = more accounts and portfolios, AI insights, Penny chat | Unchanged in code. Penny's policy check is also Pro (5/day). Savings target, recurring-cost cutter and the data-only policy check stay free | `limits.py`, `chatbot/router.py`, `savings/router.py` on `main` |
| Who gets Pro | Free by default, Pro after PayFast | **Every new account is created as Pro** (a deliberate promo in `subscriptions/deps.py`), with no end date yet | `deps.py` on `main` |
| Payment route | PayFast in-app checkout (sandbox credentials); Tiaan: "sideload testing only" | **A 2026-10-21 plan changes this:** Play Billing from January 2027, in-app PayFast removed, Pro free until 28 Feb 2027 via `PRO_PROMO_UNTIL`. Status "planned, not started" | `plans/founder-review-fixes.md` |
| Acceptance and streak | 0 of 6 cost-cutting boxes, streak not started | **No change recorded.** STATUS.md still shows 0 of 6 and no streak | `STATUS.md` §2 |
| Backups | Not installed | Still not installed (STATUS #6) | `STATUS.md` §3 |

**The conflict to settle first.** Tiaan's 10-19 answer 4 was "sideload testing only", and STATUS #17 records it. The 10-21 plan picks Google Play Billing in January. Both cannot be the plan. This report treats the 10-19 answers as settled (as asked) but prices both routes, because the 10-21 plan is newer and more detailed. **Open question 1 in §11 asks Tiaan to pick one.**

---

## 1. Verdict

**Still don't turn on paid Pro. The 10-19 verdict stands, and the research sharpens it in three ways.**

1. **n = 1 is still unproven.** Nothing in STATUS.md has moved on the 14-day streak or the 6 acceptance boxes since 10-19. This remains the first gate (unchanged from 10-19).
2. **"Stop the debit order" is not the product, because the banks already do it for free.** FNB, Standard Bank and Nedbank let customers stop or reverse a debit order inside their own app, and Absa lets them reverse one (§6.3), at no or low cost (exact fees mostly not stated). What no SA bank app does is show recurring costs **across** banks. Pro has to sell "finds every recurring cost on every account you have, and tells you which bank button to press", not the cancelling itself. **vs 10-19:** same direction ("Free tracks your money. Pro finds you money"), narrower claim.
3. **Expect about 2% to pay, not 5%.** RevenueCat's 2026 benchmark puts median download-to-paid at 2.0% by day 35, with Middle East and Africa trial-to-paid at about 57% of North America's rate (19.5% vs 34.2%, §6.4). **vs 10-19:** the 5% assumption is withdrawn; break-even is unaffected (still single-digit Pro users), but R5,000/mo of revenue now needs about 5,100 users, not about 2,000.

**And one decision is now blocking:** sideload-only (10-19 answer) or Google Play Billing in January (10-21 plan). §7 recommends Play Billing for the paid launch, which means revisiting answer 4.

R49/mo, with a R29 founding price for 12 months, is still the right launch price (§6).

---

## 2. What was reviewed

| Source | What it gave |
|---|---|
| `reviews/2026-10-19-founder-pricing-full.md` and short version | Baseline; Tiaan's answers in §11 |
| `STATUS.md` (2026-10-13, partly updated 2026-10-19) | Goals, acceptance, open threads |
| `plans/founder-review-fixes.md` (2026-10-21) | Play Billing decision, Pro promo end date, P0 bugs |
| `plans/next-goal-friends-family-beta.md`, `plans/cost-cutting-plan.md` | Beta design, savings and insurance design |
| Backend `origin/main` (`d35db82`): `subscriptions/limits.py`, `deps.py`, `config.py`, `chatbot/router.py`, `insights/router.py`, `savings/router.py` | What is gated, default tier, price |
| App `origin/master` (`1e9f57c`): `pubspec.yaml`, `AndroidManifest.xml` | Version; permissions (notification listener, camera, biometric; **no SMS permission**) |
| `piggybank-status` on fynbos-server (read-only) | Deployed SHA, container health |
| Web research, 2026-10-24 (three parallel research passes, about 110 tool calls) | Banks, competitors, Play policy, gateways, Tavily, benchmarks, POPIA, debit orders |

**Founder skills run:** validate-idea (§4), persona-gen (§4.2), competitor-matrix (§6.3), pricing-strategy (§6), mvp-scope (§5), go-to-market (§8), user-interviews (§8.3), metrics-dashboard (§8.4).

---

## 3. The product today

**What it does (1.0.10+11):** captures bank notifications (including SMS, which arrive as notifications) into a one-tap review queue, imports CSVs, and covers budgets, goals, net worth, loans, TFSA and RA trackers, a savings target with a recurring-cost cutter, an insurance check, and Penny (local Ollama).

**Tiers as built (`main`, 2026-10-24):**

| | Free | Pro |
|---|---|---|
| Accounts / portfolios | 3 / 1 | 999 / 999 |
| AI insights, Penny chat | No | Yes (chat 20/min) |
| Penny policy research | No | Yes (5 checks/day) |
| Savings target, recurring-cost cutter, data-only policy check | Yes | Yes |
| Auto-capture, CSV import | Yes | Yes |
| Price | R0 | R49.00/mo (`subscription_price_zar`) |
| **Default for a new sign-up** | | **Pro, with no end date** (`deps.py`: "deliberate, temporary promo") |

**Billing state:** PayFast code still on `main` with sandbox defaults. The 10-21 plan removes it (not started). No live merchant account (Tiaan, 10-19). **Effect:** nobody can be charged today, and nobody needs to be: every user is on free Pro.

---

## 4. Problem validation (validate-idea)

### 4.1 Assessment

The pain is real and measurable in SA right now: 36% of consumers expected to miss at least one bill or loan payment in Q3 and Q4 2025 ([TransUnion](https://newsroom.transunion.co.za/nearly-7-in-10-south-africans-remain-optimistic-about-finances-amid-rising-costs-and-fraud-risks/)), rising to 39% in Q2 2026 ([Daily Investor, snippet](https://dailyinvestor.com/finance/146180/39-of-south-africans-expect-to-miss-at-least-one-bill-repayment/)). What is **not** proven is the specific claim that people carry forgotten recurring costs worth finding. No SA survey measures forgotten subscriptions or debit orders (Not found), and 34% of consumers already cancelled subscriptions themselves in Q4 2025 ([Daily Investor citing TransUnion, snippet](https://dailyinvestor.com/finance/116598/south-african-households-in-dire-straits-2/)), which suggests much cutting is deliberate rather than discovered.

### 4.2 The five fatal questions

**Q1. Who pays, and would they pay today?** The likely payer is a salaried 22 to 35-year-old Android user with 2 or more bank products and 5 or more debit orders (personas below). Willingness to pay today: **low until shown a rand number.** Free budgeting is everywhere (FNB nav» Money, Nedbank MoneyTracker, Discovery's Financial Analyser, Vault22's free tier; §6.3). Only a found saving larger than the fee makes R49 an easy yes. Rating: maybe, which per the skill counts as a no until the beta shows otherwise.

**Q2. Why hasn't someone built this?** Several have tried parts of it. 22seven (Old Mutual) charged a fee and then went free in 2014 ([Fin24](https://www.fin24.com/Tech/News/SA-cash-management-app-22seven-goes-free-20140902)), and 22seven.com now redirects to [Vault22](https://vault22.com/), which names 22seven Financial Services and lists Old Mutual among its shareholders. SMS-reading trackers exist: Expenza (2012, [JustMoney](https://www.justmoney.co.za/articles/expenza-app-review/)), Zaka Manager ([Vuk'uzenzele, 2024](https://www.vukuzenzele.gov.za/get-handle-your-finances)) and Budge AI (launched July 2026, [LaunchBase Africa](https://launchbaseafrica.com/2026/07/16/no-bank-account-needed-inside-budge-ais-plan-to-fix-personal-finance-in-markets-open-banking-left-behind/)). **None found focuses on recurring costs across banks.** What is different now: debit-order dispute windows shrank from 365 to 60 days on 13 April 2026 ([PASA FAQ](https://pasa.org.za/wp-content/uploads/2026/04/PASA_DODE_FAQ_v3.pdf)), so catching an unwanted debit fast is worth more than it was.

**Q3. Distribution advantage?** Weak. No built-in loop yet; the first 100 users come from Tiaan's own network (Bossie's Gym, Fynbos contacts, family). A "found R___/mo" share card is the only loop candidate (§8).

**Q4. Business or feature?** Mostly a feature at risk of being absorbed: Discovery Bank already lists and suspends card subscriptions per card ([Daily Maverick, May 2025](https://www.dailymaverick.co.za/article/2025-05-07-how-to-outsmart-rising-subscriptions/)). The defensible part is cross-bank coverage, which a bank has little reason to build. Ceiling, **Estimate:** a side-income business, not a venture. R1M a year (about US$55k at R18/US$, an estimate rate) needs 1,700 Pro users at R49 (1,000,000 ÷ 12 ÷ 49), which at 2% conversion means about 85,000 users.

**Q5. Can the founder build it?** Yes, and has: the product exists. The hard part is operational, not technical: bank-notification parsing per bank, POPIA, and time (Tiaan works full-time and runs Fynbos in the evenings).

### 4.3 Scorecard

| Dimension | Score | Notes |
|---|---|---|
| Problem severity | 4 | Household stress data above |
| Market size | 3 | SA Android salaried users; no sized figure found |
| Willingness to pay | 2 | Free alternatives; 2% median conversion |
| Competition gap | 3 | Cross-bank recurring-cost view is open; budgeting is not |
| Distribution | 2 | Warm network only |
| Timing | 3 | 60-day dispute window; household stress |
| Founder fit | 3 | Built it and uses SA banks; limited hours |
| **Total** | **20/35** | "Significant concerns" band (14 to 20) |

**vs 10-19:** the 10-19 report did not score; this is new. The weakest dimensions are willingness to pay and distribution, so the next experiments target those.

### 4.4 Three validation experiments (under 2 weeks, under R3,500 each)

| # | Assumption | How | Success | Cost |
|---|---|---|---|---|
| 1 | Tiaan has forgotten recurring costs worth cutting | Back-fill 3 to 6 months of CSVs, run the cutter, mark cuts | R200/mo or more marked "cut" | R0, about 3 hours |
| 2 | Other people do too | "Debit-order audit" for 5 people from the warm network: they import 3 months of CSV into the beta app; Tiaan sits with them for 20 minutes; they delete or keep their data as they choose | 3 of 5 mark R150/mo or more as "cut" | R0 to R500 (coffee) |
| 3 | They'd pay | At the end of experiment 2, offer the R29 founding price for 3 months, paid by EFT now. **Needs Tiaan's go**, because no gateway is live | 2 of 5 actually pay | R0 |

### 4.5 Personas (persona-gen)

These are hypotheses until the beta interviews (§8.3) confirm them. Incomes are illustrative, not sourced.

| | **Thandi (primary)** | **Ruan (secondary)** | **Naledi (tertiary)** |
|---|---|---|---|
| Who | 27, Johannesburg, junior accountant, about R28k/mo | 31, Pretoria, IT support, about R35k/mo, saving to move out | 44, Durban, teacher, household of 4, about R30k/mo |
| Banks | Capitec day-to-day, FNB credit card | Standard Bank, Discovery credit card | Nedbank, a store card |
| Recurring costs | Gym, phone contract, 2 streaming services, funeral policy | Car insurance, medical aid, 3 subscriptions, a loan | Funeral policies, school fees, insurance, phone contracts |
| Pain, in her or his words | "I know money leaves on the first, I just don't know where." | "I need R6k a month for rent and I can't see where to find it." | "There's a debit order for R89 I don't recognise and the bank says I'm too late." |
| Workaround | Scrolls the banking app on payday; screenshots | A spreadsheet updated every few months | Paper statements; calls the bank |
| Pay trigger | The app shows a rand total she can act on | A visible gap to his target closing | A debit order caught inside 60 days |
| Urgency / WTP / Reach (1 to 5) | 4 / 3 / 4 | 5 / 3 / 5 | 4 / 2 / 2 |

**Build for Thandi first:** she is reachable through the warm network and has the most recurring costs across more than one bank, which is exactly the gap §6.3 finds. Ruan is Tiaan himself, which is useful for n = 1 but biased.

---

## 5. MVP scope for beta wave 1 (mvp-scope)

**MVP in one sentence:** a tester can import 3 months of statements and see every recurring cost across their banks, with a rand total they could cut, in under 10 minutes.

| Feature | Category | Why |
|---|---|---|
| CSV import (all banks) | Must have | Detection needs history; capture alone starts from today |
| Merchant-level recurring detection + confirm/dismiss | Must have | The core value; nothing else in SA does it across banks |
| Savings target + gap, "savings found" total | Must have | The rand number that drives both habit and upgrade |
| Auto-capture + one-tap review | Must have | Keeps the list current after the import |
| In-app feedback ("Report a problem", 10-21 plan PR 3) | Must have for beta | Testers won't message Tiaan about every bug |
| **"Where to stop it" link per bank** (new) | Should have | Banks already have stop and reverse buttons (§6.3); Piggybank points to them. Low build cost: a static table per bank |
| **New-debit-order alert with 60-day countdown** (new) | Should have | Matches the PASA change; only valuable after capture works for the tester's bank |
| Insurance check (data only) | Should have | Strong for Ruan and Naledi, not needed to prove the core loop |
| Penny chat, policy research | Won't have in beta | 3B model; wrong money answers cost trust |
| TFSA, RA, portfolios, calculators, net-worth hub | Won't have in beta | Specialist; hide behind "More" (unchanged from 10-19) |
| Household tier | Won't have | Needs shared-account modelling; revisit at 100 Pro users |
| iOS | Won't have | Manual-only on iOS; revisit after wave 1 |

**Critical path:** (1) install and sign up, (2) import a CSV per bank, (3) see "Found N recurring costs, R X/mo", (4) confirm or dismiss each, (5) mark one "cut". Steps 3 to 5 should take under 3 minutes.

**Launch criteria for wave 1** (unchanged gates from 10-19, plus two): off-host backups and `make restore-check`; device pass 2 on mobile data; Information Officer registered; feedback channel live; **Pro promo end date set** (10-21 plan PR 1); **a redacted notification fixture for each tester's bank** (10-21 plan PR 3 item 6). Can be rough: visual polish on secondary screens, the Penny tab.

**The one thing to test with the first 10 users:** do they mark at least one cost as "cut" within 7 days?

---

## 6. Pricing (pricing-strategy)

### 6.1 Model fit

Unchanged from 10-19: **freemium + monthly and annual subscription** scores 5/5 against flat (3), one-time (2), usage, seat and credits (1 each). One new reason: RevenueCat 2026 finds Middle East and Africa has the highest share of monthly plans (about 52 to 55%) ([RevenueCat SOSA 2026](https://www.revenuecat.com/state-of-subscription-apps/)), so lead with monthly.

### 6.2 Tier design

| | **Free** | **Pro** (target) | **Household** (deferred) |
|---|---|---|---|
| Monthly | R0 | **R49** (founding R29, 12 months) | R79 |
| Annual | R0 | **R490** (2 months free) | R790 |
| Accounts | 3 | Unlimited | Unlimited, 2 logins |
| Auto-capture, one-tap review, budgets (3), 1 goal | Yes | Unlimited | Unlimited, shared |
| CSV import | 3 months | Unlimited history | Unlimited |
| Recurring-cost detection | **Count and rand total** ("9 recurring costs, R1,240/mo") | Full list, cut tracking, savings total, "still charged" alerts | Yes |
| New-debit-order alert | Yes (builds trust and habit) | Yes, plus 60-day countdown and the bank's stop steps | Yes |
| Insurance check | No | Up to 5 policies, Penny research | Up to 10 |
| Penny | 5 questions/month | Unlimited (rate-limited) | Unlimited |
| Upgrade trigger | Seeing a rand total you can't act on | Adding a partner | n/a |

**vs 10-19:** same prices and the same **proposed** Free/Pro line as 10-19, which is **not built yet**: today the cutter and the data-only policy check are free and Penny is Pro-only (§3). This table is the target; §10 move 8 builds it. **New:** the new-debit-order alert is free, because its value is trust and daily opens, and the countdown plus stop steps are Pro. Household stays deferred until after the beta.

### 6.3 Competitive context (competitor-matrix)

**SA bank apps (checked 2026-10-24):**

| Bank | Budgeting | Stop or reverse a debit order in-app | Source |
|---|---|---|---|
| FNB | nav» Money, described as free (snippet) | Stop: yes (5 business days before). Dispute R200 or less in-app within 40 days | [FNB](https://www.online.fnb.co.za/security-centre/fraud-and-disputes.html), [BusinessTech](https://businesstech.co.za/news/banking/250773/fnb-launches-new-nav-money-tool/) |
| Capitec | Spending categorisation (snippet) | Can view DebiCheck mandates; suspend button **not confirmed** | [Capitec](https://www.capitecbank.co.za/personal/transact/types-of-debit-orders/) (snippet) |
| Absa | None found | View; reverse up to R500 within 40 days | [Absa](https://www.absa.co.za/help/how-to-manage-accounts-online/) |
| Standard Bank | Money Movements and Budget Manager add-ons (price not stated) | Stop and reverse in-app (the page gives conflicting limits) | [Standard Bank app](https://www.standardbank.co.za/southafrica/personal/products-and-services/ways-to-bank/self-service-banking/mobile-app-banking), [stop a debit order](https://www.standardbank.co.za/southafrica/personal/learn/how-to-stop-debit-orders) |
| Nedbank | MoneyTracker, "free", Nedbank accounts only | Reverse, then stop; 60-day disputes from 13 April 2026 | [Nedbank](https://personal.nedbank.co.za/bank/digital-banking/needs/manage/money-tracker.html), [Nedbank disputes](https://personal.nedbank.co.za/learn/help-centre/bank/dispute-debit-order.html) |
| Discovery | Financial Analyser, budgets from 3 to 12 months of history | Lists and suspends **card subscriptions** per card | [Discovery](https://discovery.co.za/bank/info-and-tips-financial-education-tools), [Daily Maverick](https://www.dailymaverick.co.za/article/2025-05-07-how-to-outsmart-rising-subscriptions/) |
| GoTyme (was TymeBank) | GoalSave only | Disputes via call centre | [GoTyme FAQ](https://gotyme.co.za/personal/help/faqs) |

**No SA bank app found aggregates other banks' accounts.** The banks' in-app reversal limits (FNB and Absa: within 40 days) are a self-service limit; the industry dispute right is 60 days since 13 April 2026 ([PASA FAQ](https://pasa.org.za/wp-content/uploads/2026/04/PASA_DODE_FAQ_v3.pdf)).

**Apps:**

| App | Price (checked 2026-10-24) | Recurring-cost detection | SA banks | Source |
|---|---|---|---|---|
| Vault22 (ex-22seven) | Free, Basic, Premium; ZAR prices not shown | Not named | Account linking | [vault22.com/pricing](https://vault22.com/pricing) |
| Spendee | Free; Plus US$1.99/mo; Premium US$5.99/mo | Not named | Not mentioned | [spendee.com/pricing](https://www.spendee.com/pricing) |
| Wallet (BudgetBakers) | Not on official page | Planned payments (manual) | Not mentioned | [budgetbakers.com](https://budgetbakers.com/en/products/wallet/) |
| Zaka Manager (SA) | Not found | Not named | SMS + statements, "all major SA banks" | [Vuk'uzenzele](https://www.vukuzenzele.gov.za/get-handle-your-finances) |
| Budge AI (Africa) | Freemium, Pro price untested | Not named | SA not mentioned | [LaunchBase Africa](https://launchbaseafrica.com/2026/07/16/no-bank-account-needed-inside-budge-ais-plan-to-fix-personal-finance-in-markets-open-banking-left-behind/) |
| Rocket Money (US reference) | Free; Premium US$7 to US$14/mo; Premium+ US$15/mo | Yes, free tier | No SA | [Rocket Money](https://www.rocketmoney.com/learn/personal-finance/how-much-does-rocket-money-cost) |
| Emma (UK reference) | £4.99 to £14.99/mo | Unknown | No SA | [Emma help](https://help.emma-app.com/en/article/1ywhulq/) |

**Feature matrix:**

| Feature | Piggybank | Bank apps | Vault22 | Zaka | Budge AI | Rocket Money |
|---|---|---|---|---|---|---|
| Auto-capture from notifications/SMS | Building (shipped) | n/a | No | Yes | Yes | No |
| Cross-bank view | Yes (capture + CSV) | No | Yes | Yes | Unknown | Yes (US) |
| Recurring-cost detection across banks | Yes | No | Unknown | Unknown | Unknown | Yes (US) |
| Stop or reverse a debit order | No (links out) | Yes (own bank) | No | No | No | Partial (cancels for you) |
| New-debit-order alert | Planned | Partial (Nedbank approve/reject prompt) | Unknown | Unknown | Unknown | Unknown |
| Insurance premium check | Yes | No | Unknown | Unknown | Unknown | Unknown |
| AI assistant | Yes (local) | No | Yes ("Tara") | Partial ("AI spend tracking") | Yes ("Ask Budge") | Unknown |
| Data processed in SA | Yes | Yes | Unknown | Unknown | On-device | No |

Sources for the matrix: Piggybank from the repo; bank cells from the bank table above plus [Nedbank approve/reject](https://personal.nedbank.co.za/learn/help-centre/bank/approve-or-reject-a-debit-order.html); Vault22 from [vault22.com](https://vault22.com/); Zaka from [Vuk'uzenzele](https://www.vukuzenzele.gov.za/get-handle-your-finances); Budge AI from [LaunchBase Africa](https://launchbaseafrica.com/2026/07/16/no-bank-account-needed-inside-budge-ais-plan-to-fix-personal-finance-in-markets-open-banking-left-behind/); Rocket Money from [its pricing article](https://www.rocketmoney.com/learn/personal-finance/how-much-does-rocket-money-cost). "Unknown" means the source did not say.

**Positioning gap:** "every recurring cost on every account, in one list, with the stop button for each bank." Build difficulty: low to medium (detection exists). **Head start, Estimate:** 6 to 12 months. Reasoning, not arithmetic: Vault22 already aggregates, so adding a recurring-cost tab is one product cycle for a funded team (assumed 6 to 12 months from decision to release); banks have no reason to show competitors' accounts.

**Threats:** (1) **Vault22**, high: Old Mutual-backed, already aggregates, could add a subscriptions tab. (2) **Discovery Bank**, medium: already suspends card subscriptions, but only its own cards. (3) **Budge AI**, low to medium: same capture method, new in July 2026, SA not confirmed.

**vs 10-19:** 22seven was "free"; it is now Vault22 with paid tiers, prices Not found. YNAB was the 10-19 price comparison; it is dropped as irrelevant to SA.

### 6.4 Unit economics

**Variable cost per Pro user per month at R49** (exchange rate Estimate: R18/US$, the 10-19 assumption):

| Item | Arithmetic | R/user/mo |
|---|---|---|
| Penny on local Ollama | Estimate (10-19): the GPU already runs for other work, so only marginal power per chat | ~R0 to R1 |
| Anthropic fallback (if enabled) | Estimate (10-19): 100 chats × (3,000 in + 500 out) tokens at [US$0.10/M in, US$0.50/M out](https://platform.claude.com/docs/en/about-claude/pricing) = US$0.03 + US$0.025 = US$0.055 × R18 | ~R1 |
| Tavily, policy research | 1,000 free credits/mo; basic search 1 credit; pay-as-you-go US$0.008/credit ([Tavily credits](https://docs.tavily.com/documentation/api-credits), [pricing](https://www.tavily.com/pricing)). Estimate: 10 checks × 3 searches = 30 credits/user, so the app's 800-credit budget (`config.py` `web_search_monthly_budget`) covers about 26 users; beyond that 30 × 0.008 × 18 | R0 up to ~26 users, then ~R4.32 |
| **Fee, option A: Play Billing** | 15% outside the US, UK, EEA, AU and JP ([Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)): 0.15 × 49 | **R7.35** |
| **Fee, option B: Payfast (web only)** | 3.2% + R2.00 ex VAT ([Payfast fees](https://payfast.io/fees/)): (0.032 × 49 + 2) × 1.15 | **R4.10** |
| **Fee, option C: Paystack (web only)** | 2.9% + R1.00 ex VAT (snippet, [Paystack support](https://support.paystack.com/hc/en-us/articles/360009881920)): (0.029 × 49 + 1) × 1.15 | **R2.78** |
| **Fee, option D: Play user choice billing + Payfast** | Play's fee drops 4 points on alternative-billed sales ([user choice billing](https://support.google.com/googleplay/android-developer/answer/13821247)), so Estimate: 0.11 × 49 + R4.10 | **R9.49** (the worst option) |

**Gross margin at R49** (variable cost R2 plus fee): Play (49 − 7.35 − 2) ÷ 49 = **81%**; Payfast 88%; Paystack 90%; user choice billing (49 − 9.49 − 2) ÷ 49 = 77%. **At the R29 founding price:** Play (29 − 4.35 − 2) ÷ 29 = **78%**; Payfast (29 − 3.37 − 2) ÷ 29 = 81%. **vs 10-19:** Play and Payfast margins unchanged; Paystack and user choice billing are new.

**Fixed costs** (Estimates unless linked): host power and internet share about R150/mo and domain about R25/mo (10-19 estimates, not itemised further). **Monthly total about R175/mo**, unchanged. Not in that total: Play registration US$25 once ([Play Console](https://support.google.com/googleplay/android-developer/answer/6112435)), about R450 at R18/US$; Payfast R8.70 per payout ([Payfast fees](https://payfast.io/fees/)) if a web route is ever used.

**Break-even:** R175 ÷ R39.65 (Play net at R49) = 4.4, so **5 Pro users**; at R29, R175 ÷ R22.65 = **8 founding users**.

**Conversion and ARPU.** RevenueCat's 2026 report (2025 data) gives median download-to-paid of **2.0%** by day 35, with no separate Finance category (Finance sits inside Utilities) ([RevenueCat](https://www.revenuecat.com/state-of-subscription-apps/)). Middle East and Africa trial-to-paid is about 19.5% against 34.2% in North America, and MEA is the only region with negative median MRR growth (−9.7%) (same source). **Planning range: 1 to 3%, base 2%.** Blended ARPU at 2%: 0.02 × 49 = **R0.98 per user per month** (vs 10-19: R2.45 at 5%). R5,000/mo of Pro revenue = 5,000 ÷ 49 = 102 Pro users ÷ 0.02 = **about 5,100 users**.

### 6.5 Pricing psychology

1. **Anchor on savings found.** "Pro found R1,240/mo · Pro costs R49/mo." Unchanged from 10-19.
2. **Anchor against reference apps, not SA banks.** Rocket Money's paid tiers run US$7 to US$15/mo ([Rocket Money](https://www.rocketmoney.com/learn/personal-finance/how-much-does-rocket-money-cost)), Estimate R126 to R270 at R18/US$. R49 reads as a fair local price. Never compare against bank apps, which are free.
3. **Annual:** "R490/yr: 2 months free". Lead with monthly in the beta (MEA prefers monthly, §6.1).

### 6.6 Launch vs scale pricing

Unchanged from 10-19 and Tiaan's answer 5: beta Pro free (now until 28 Feb 2027 per the 10-21 plan); **R29/mo founding price locked 12 months** for beta testers and the first 50 payers; then the price at the time with 30 days' notice. Raise R49 to R69 only when (a) median savings found per Pro user is R500/mo or more, (b) monthly Pro churn is below 6% for 3 months, and (c) iOS has parity.

**New caution:** the Play founding price has to be a Play subscription offer or a separate product ID, because Play Billing sets the price per product. **Not checked:** the exact Play mechanism for a 12-month locked introductory price.

---

## 7. Distribution and billing compliance

| Route | Billing allowed | Fee at R49 | Notes |
|---|---|---|---|
| **A. Sideloaded APK** (Tiaan's 10-19 answer) | Any (Play policy doesn't apply) | Payfast R4.10 / Paystack R2.78 | Android **developer verification** goes global on certified devices "in 2027"; unregistered apps then need ADB or a 24-hour advanced flow ([Android Developers blog](https://developer.android.com/blog/posts/android-developer-verification-rolling-out-to-all-developers-on-play-console-and-android-developer-console), snippet). Install friction for every tester. |
| **B. Play, Play Billing only** (10-21 plan) | Required for in-app subscriptions ([Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818)) | R7.35 | SA supports merchant registration with **ZAR payouts** ([Play merchant countries](https://support.google.com/googleplay/android-developer/answer/9306917)). New personal accounts need **12 testers opted in for 14 days** before production ([Play testing](https://support.google.com/googleplay/android-developer/answer/14151465), snippet) |
| **C. Play + user choice billing** | **South Africa is eligible** for non-game apps; Play Billing must still be offered alongside ([user choice billing](https://support.google.com/googleplay/android-developer/answer/13821247)) | ~R9.49 | More expensive than B at this price, plus Alternative Billing API work. **Reject.** |
| **D. Play, no in-app purchase, pay on the web** | Allowed only as a "consumption-only" app with no link or steering in the app ([Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818)) | Payfast R4.10 | Users can't upgrade from inside the app. A poor fit for a freemium upgrade prompt. |

**Recommendation:** run wave 1 as a **Play closed test** (it costs the US$25 and serves the 12-tester gate and the pricing signal at the same time), and use **Play Billing** for the paid launch, as the 10-21 plan says. The R3.25/mo fee gap against Payfast (R7.35 − R4.10) is small next to the install friction of sideloading and the 2027 verification change. Keep a gateway (Paystack is cheapest on paper; Payfast's KYC is documented and needs no CIPC registration, [Payfast KYC](https://payfast.io/?p=29694)) only for a future web sign-up. **vs 10-19:** this reverses the reading of answer 4 ("sideload only") and agrees with the 10-21 plan. **Tiaan needs to confirm** (§11, question 1).

**Play policy for notification capture:** the app requests **no SMS permission** (manifest checked), so Play's SMS and Call Log policy, which has a temporary "SMS-based money management" exception ([Play SMS policy](https://support.google.com/googleplay/android-developer/answer/10208820)), does not apply. Every published app must still complete the **Financial features declaration** ([Play](https://support.google.com/googleplay/android-developer/answer/13849271), snippet). **Not found:** a primary Play policy on notification-listener access, so expect a review question and have a short use-case video ready.

---

## 8. Go-to-market: from beta to the first 10 paying users (go-to-market)

### 8.1 Launch readiness

**Not ready for paying users; nearly ready for wave 1** once the §5 launch criteria are met. Biggest risk: a tester's bank isn't parsed, so their first week shows nothing.

### 8.2 Channels (first 90 days)

CAC figures are Estimates: each channel costs Tiaan's time only, with no paid spend.

| Rank | Channel | CAC (Estimate) | First action this week |
|---|---|---|---|
| 1 | Warm network: Bossie's Gym members, Fynbos contacts, family | R0 | List 20 names; pick 12 with 2 or more banks |
| 2 | Referral: 1 month Pro free for both people | ~R0 variable | Add a referral code field before wave 2 |
| 3 | [r/PersonalFinanceZA](https://www.reddit.com/r/PersonalFinanceZA/) (about 43,000 members in May 2025, [Financial Mail](https://fm.co.za/2025-05-27-south-africa-s-financial-advisers-family-friends-and-facebook/)) | R0 | Read the rules; post a useful "how to find every debit order on your statement" guide, not an ad, after the beta |
| 4 | SA forums where debit-order complaints already happen, e.g. [4x4Community debit-order threads](https://www.4x4community.co.za/forum/showthread.php/336099-Unauthorised-Debit-orders) | R0 | Answer questions; no links until allowed |
| 5 | Content: "The 60-day debit order rule" explainer, citing [PASA](https://pasa.org.za/wp-content/uploads/2026/04/PASA_DODE_FAQ_v3.pdf) | R0 | Draft it; publish when Play listing is live |

**Message:** "Find every debit order and subscription on all your accounts, before your 60 days to dispute run out." Don't promise a reversal: PASA says reversals are "neither automatic nor guaranteed" (same source). Not "AI budgeting app" (unchanged from 10-19).

Product Hunt, Hacker News and X don't fit an SA-only consumer finance app; skip them. **Budget:** R0 in the beta; the one paid item worth it is the Play registration (US$25).

### 8.3 Beta interview script (user-interviews), 25 minutes

**Assumptions to test:** (1) testers have recurring costs they didn't know about; (2) they act on a found cost within a week; (3) they'd pay R29 to R49 for that.

**Screen:** salaried, Android, 2 or more bank products, 5 or more debit orders; exclude anyone who works in banking or is close family who'll be polite.

**Opening (2 min):** "Thanks for testing Piggybank. I'm trying to learn what's broken, so the most useful thing you can do is be blunt. Nothing you say will hurt my feelings. Can I take notes?"

**Problem, past behaviour only (10 min):**
1. "Tell me about the last time a debit order or subscription surprised you." (When? How much? What did you do?)
2. "Walk me through how you checked your money last month." (Which apps? How long?)
3. "What have you cancelled in the last year? How did you notice it?"
4. "Have you ever tried to stop or reverse a debit order? What happened?"
5. "Before Piggybank, did you ever pay for anything to help with this? What?"

**Their solution first (5 min):** "If you could fix this any way you liked, what would happen?" Note features they name unprompted.

**Reaction (5 min):** "Piggybank found [their number] in recurring costs across your accounts." Then: "Which of these did you actually cancel? What stopped you on the others?"

**Commitment test (3 min):** "The founding price is R29 a month, locked for a year. Would you sign up today?" Then the four price questions (too cheap / bargain / getting expensive / too expensive). Ask for one referral.

**Red flags:** "sounds cool", future tense, feature requests. **Real signals:** a cost already cancelled, a specific rand amount, asking when paid Pro opens.

### 8.4 Beta and launch metrics (metrics-dashboard)

**Stage:** post-launch, 0 to 100 users. Track 5 metrics weekly from Piggybank's own database (no third-party analytics, which keeps POPIA simple):

| Metric | Definition | Target day 30 / 60 / 90 | If below |
|---|---|---|---|
| Activation | % of testers who confirm 1 or more recurring costs within 7 days of sign-up | 60% / 70% / 75% | Check CSV import per bank; sit with one tester |
| Week-3 retention | % active (opened + reviewed 1 item) in week 3 without a nudge | 60% / 60% / 65% | Fix the top feedback item before adding testers |
| Auto-capture share | % of transactions captured automatically, per bank | 80% (the daily-driver bar) | Add that bank's fixture and parser |
| Savings found | Median R/mo marked "cut" per active tester | R150 / R250 / R300 | Re-check detection; interview on why costs weren't cut |
| Pay intent | % of interviewed testers who accept the R29 commitment test | n/a / 30% / 40% | Revisit the Pro line or the price |

**Ignore:** total sign-ups, APK downloads, Penny message counts. **Weekly review:** one SQL query per metric, 15 minutes, written into the runbook.

---

## 9. Risk register

| # | Risk | Likelihood | Impact | Mitigation | vs 10-19 |
|---|---|---|---|---|---|
| 1 | Monetisation before daily use | High | High | Gate paid launch on the streak + real cutter result | Same |
| 2 | No backups on real financial data | High (today) | Severe | STATUS #6 before any invite | Same |
| 3 | POPIA gaps: Information Officer unregistered; s18 notice and s72 basis for Anthropic/Tavily transfers | Medium | High | Register on the [eServices portal](https://eservices.inforegulator.org.za/about/default.aspx) ([s55 registration guide](https://inforegulator.org.za/wp-content/uploads/2025/02/Registration.pdf)); s18 notice names each transfer ([s18](https://popia.co.za/section-18-notification-to-data-subject-when-collecting-personal-information/)); s72 basis = consent or an adequate-protection agreement ([s72](https://popia.co.za/section-72-transfers-of-personal-information-outside-republic/)); breach reports via the portal since 1 April 2025 ([Covington](https://www.insideprivacy.com/data-security/data-breaches/south-africa-introduces-mandatory-e-portal-reporting-for-data-breaches/), snippet) | Sharper |
| 4 | Distribution decision unresolved (sideload vs Play) | High | Medium | §7 recommendation; Tiaan decides | New |
| 5 | Conversion near 2%, not 5% | High | Medium | Plan on 2%; measure pay intent in the beta | New |
| 6 | Banks already stop debit orders for free | Certain | Medium | Sell finding across banks, link to the bank's own stop button | New |
| 7 | Vault22 adds recurring-cost detection | Medium | High | Move first on the cross-bank recurring list; watch its changelog | New |
| 8 | Penny gives a wrong money answer | Medium | High | Hide open chat in beta; Python-computed facts | Same |
| 9 | A tester's bank isn't parsed | High | Medium | Redacted fixtures per bank before invites (10-21 PR 3) | Same |
| 10 | Android developer verification in 2027 | High if sideloading | Medium | Register for verification on any route | New |
| 11 | Play reviews notification-listener use | Medium | Medium | Clear in-app disclosure; Financial features declaration; demo video | New |
| 12 | Tiaan's time split with full-time job and Fynbos | High | Medium | Small sprints | Same |

---

## 10. Recommended next moves

| # | Move | Owner | When |
|---|---|---|---|
| 1 | Run the cutter on real data (experiment 1) and start the 14-day streak | Tiaan | This week |
| 2 | Decide sideload vs Play closed test + Play Billing (§7) | Tiaan | This week |
| 3 | Update STATUS.md: #32 deployed (`f3112be` on host), 1.0.10+11, the 10-21 plan, and the distribution decision | Claude (docs), on Tiaan's go | After move 2 |
| 4 | Backups + `make restore-check`; Information Officer registration on eServices | Tiaan | Before invites |
| 5 | Land 10-21 plan PR 1 (Pro expiry, PayFast removal) | Claude | Before wave 1 |
| 6 | Add "where to stop it" per bank and the new-debit-order alert to the beta scope | Claude (plan, then PRs) | Before wave 1 |
| 7 | Run experiment 2 (5-person debit-order audit) with the §8.3 script | Tiaan | Within 2 weeks of move 1 |
| 8 | Move the Free/Pro line (§6.2) | Claude (backend + app PRs) | After the beta, before paid launch |
| 9 | Check Vault22's ZAR prices and features on its Play listing | Claude (research) | Before paid launch |

---

## 11. Open questions for Tiaan

1. **Distribution:** your 10-19 answer was sideload only; the 10-21 plan chose Play Billing from January. Which stands? (Recommendation: Play closed test for the beta, Play Billing for paid, §7.)
2. **Pro promo end:** is 28 Feb 2027 the end of free Pro for beta testers, with R29 founding pricing from 1 March 2027?
3. **Experiment 3:** OK to take a real R29 EFT from 2 to 5 testers before a gateway exists, or only ask the question?
4. **New beta scope:** add "where to stop it" per bank and the new-debit-order alert (§5)?

The 10-19 answers (earn money; not VAT-registered; no live PayFast merchant; R29 founding price approved) are treated as settled.

---

**Not checked / Not found:**
- SA app-store consumer spend 2023 to 2026; SA survey data on forgotten subscriptions or debit orders; SA subscription-fatigue or app price-sensitivity surveys
- A Finance-only conversion benchmark (RevenueCat folds Finance into Utilities); Adapty reports
- Vault22's ZAR prices and supported banks; Zaka Manager's price and whether it is still live; funding for Spendee, Zaka and Budge AI; ZAR Play prices for Wallet and Spendee
- Capitec's in-app debit-order suspend; Standard Bank add-on prices; Capitec and Standard Bank dispute fees (snippets may be stale)
- Paystack's SA pricing page (returned 403, figures from a support snippet) and payout schedule; Yoco and Ozow recurring billing
- When Play's new fee structure reaches SA; whether Play's 15% includes SA VAT; the Play mechanism for a 12-month locked founding price
- Primary Play policy text on notification-listener access
- Official Regulator guidance on Information Officer registration for a sole proprietor; Regulator action on apps that read notifications
- PASA's own 2024 to 2026 debit-order volumes and dispute counts (only secondary sources were found, so no volume figure is used)
- The R18/US$ exchange rate is an estimate throughout
- Snippet-only figures (marked) were not opened in full
