# Piggybank: founder and pricing review (full report)

**Date:** 2026-10-19 · **Author:** Claude for Tiaan · **Scope:** read-only review of product, pricing, beta plan and go-to-market
**Short version:** `reviews/2026-10-19-founder-pricing.md`

---

## 1. Verdict

Don't turn on paid Pro yet. The pricing is wired up, but three things come first:

1. **Prove n = 1.** Tiaan has not yet run the 14-day streak, and 0 of the 6 cost-cutting acceptance boxes are ticked (STATUS.md §2). Nobody has shown that the app changes a real month's spending.
2. **Pro is gating the wrong feature.** Pro charges R49/mo for unlimited accounts plus AI, which is a 3B local chatbot. The thing people would pay for, the savings finder and recurring-cost cutter, is free.
3. **The billing route may not be allowed on Play.** The app sends users to a PayFast checkout. If Piggybank ships through Google Play in South Africa, Play's payments policy very likely requires Google Play Billing for subscriptions. That changes the fees and the integration (§7).

Once all three are dealt with, R49/mo is a sound launch price, as long as Pro is rebuilt around savings found.

---

## 2. What was reviewed

| Source | What it gave |
|---|---|
| `STATUS.md` (2026-10-13) | Shipped state, goals, open threads |
| `plans/next-goal-friends-family-beta.md` | Beta goal, waves, "Pro free in beta, ask if they'd pay" |
| `plans/cost-cutting-plan.md` | Savings target, recurring costs, insurance check design |
| `plans/research-2026-10-pre-beta-infra.md` | Third-party costs for 5 testers (Q7), POPIA notes |
| `plans/piggybank-launch-readiness.md` §Step 5 | Payment gateway options |
| App: `lib/features/settings/screens/subscription_screen.dart` | Pro feature list, PayFast checkout flow |
| Backend (via `gh`): `subscriptions/limits.py`, `payfast.py`, `router.py`, `config.py`; `savings`, `detection`, `imports` routers | Tier limits, price, which features are gated |
| Web (checked 2026-10-19) | 22seven, YNAB and PayFast prices; Google Play billing policy news |

**State corrections found today:**
- STATUS.md lists backend **#32** and app **#78** (loans anchor) as open. `gh` shows both **merged on 2026-10-13** at 17:35 UTC. Whether #32 is deployed on the host was **not checked**; Claude's host access is read-only, and that check wasn't run.
- The app README is still the Flutter boilerplate ("A new Flutter project"). That's harmless now, but it needs replacing before any public repo or tester docs.

---

## 3. The product today

**What it does (shipped in 1.0.9+10):** auto-captures bank SMS and notifications into a one-tap review queue, imports CSVs, and covers budgets, goals and net worth (accounts, assets, liabilities, loans). It also has TFSA and RA trackers, calculators, a savings target with a recurring-cost cutter and an insurance check (1.0.7), and Penny, the in-app assistant (qwen2.5:3b on the local Ollama).

**Tiers as built:**

| | Free | Pro |
|---|---|---|
| Accounts | 3 | 999 |
| Portfolios | 1 | 999 |
| AI insights + Penny chat | No | Yes |
| Savings target, recurring-cost cutter | Yes | Yes |
| Auto-capture (detection) | Yes (consent-gated) | Yes |
| CSV import | Yes | Yes |
| Price | R0 | **R49.00/mo** (`config.py` `subscription_price_zar`), PayFast recurring, monthly, until cancelled |

Sources: `limits.py`, `config.py`; the savings, detection and imports routers depend only on consent, not tier.

**Billing state:** the PayFast integration (checkout, then ITN webhook, then Pro) is built. The merchant ID, key and passphrase default to PayFast's **sandbox** credentials, and production needs them overridden. Whether a live merchant account exists: **not checked**.

---

## 4. Problem validation

**The problem, as the plans state it:** "I can't see where my money goes, and logging it by hand is a chore" (daily-driver sprint), and "I need to free up R X a month for rent" (cost-cutting plan).

| Question | Evidence | Rating |
|---|---|---|
| Is the pain real for Tiaan? | He built the cost-cutting goal around moving out | Strong |
| Does the product relieve it for Tiaan? | Streak not started. Cutter never used on real data. Use was "on and off" on 2026-10-05 | **Unproven** |
| Is the pain real for others? | No interviews or tester data yet | **Unknown** |
| Will others do the setup work? | Needs notification access, bank-specific parsers, and CSV back-fill for history | Risky |

**Who the likely user is** (assumption; test it in the beta): a South African aged roughly 22 to 35, on Android, with a salary, 3 or more debit orders and subscriptions, a concrete monthly goal (rent, a car, moving out), and no financial adviser.

**What would count as validation:** in wave 1, at least 3 of 5 testers still active after 3 weeks without nudging (already the beta's own success test), **and** at least one tester whose cutter shows R200/mo or more marked "cut".

---

## 5. MVP scope for beta wave 1

Piggybank has a broad surface for a beta of 3 to 5 people. A tester's first week should touch only the core loop.

| Keep front and centre | Hide or de-emphasise in beta | Why |
|---|---|---|
| Auto-capture + one-tap review | TFSA tracker, RA tracker | Core loop vs specialist tools |
| Home: today's spend, "N to review" | Portfolios, net-worth hub | Few testers will have portfolios |
| Savings target + gap | Calculators | Nice to have |
| Recurring-cost cutter + "savings found" total | Penny's open chat | 3B model; wrong answers hurt trust in money numbers |
| CSV back-fill (needed so detection has history) | Insurance market read (needs Tavily, still unset) | Blocked by a decision anyway |

**Hard gates before any invite** (all from STATUS.md §3): off-host backups plus `make restore-check` (#6), device pass 2 on mobile data (#1), the Information Officer registered (#11), and the in-app feedback channel (beta plan Phase B).

"Hide" means move behind a "More" entry or an onboarding default. Nothing needs deleting.

---

## 6. Pricing

### 6.1 Model fit

| Model | Fit (1 to 5) | Pros | Cons |
|---|---|---|---|
| Flat subscription | 3 | Simple, and PayFast recurring is already built | Users must see value every month or churn |
| Usage-based | 1 | Matches Penny's cost | Consumers hate metered money apps; cost per use is near R0 anyway |
| Per seat | 1 | Not applicable | Personal app |
| **Freemium + subscription** | **5** | The capture habit is free; you pay when it finds money; matches the existing Free/Pro split | Needs the right line between free and paid (see 6.2) |
| Credits | 1 | Not applicable | Adds friction |
| One-time purchase | 2 | Easy sell in SA | Running costs are ongoing (host, Tavily, AI fallback) |

**Recommendation: freemium with a monthly and annual subscription.** Free has to build the daily habit, because without data nothing else works. Pro has to sell an outcome you can measure in rand.

### 6.2 Tier design

**The current line is wrong.** "Unlimited accounts + AI" asks people to pay for capacity and a chatbot. Change it to "Free tracks your money. Pro finds you money."

| | **Free** | **Pro** (target tier) | **Household** |
|---|---|---|---|
| Monthly | R0 | **R49** | R79 |
| Annual | R0 | **R490** (2 months free, 17% off) | R790 (17% off) |
| Accounts | 3 | Unlimited | Unlimited, 2 logins |
| Auto-capture + one-tap review | Yes | Yes | Yes |
| CSV import | 3 months of history | Unlimited history | Unlimited |
| Budgets, goals | 3 budgets, 1 goal | Unlimited | Unlimited, shared |
| Savings target + gap | Yes, as a teaser: shows the gap | Yes | Shared household target |
| Recurring-cost cutter + "savings found" | Shows the **count** of recurring costs found | Full list, cut tracking, savings total | Yes |
| Insurance premium check | No | Yes (up to 5 policies) | Yes (up to 10) |
| Penny | 5 questions/month | Unlimited (rate-limited) | Unlimited |
| **Upgrade trigger** | "Piggybank found 9 recurring costs worth R1,240/mo. See which to cut." | Adding a partner | Not applicable |

**Why this works:** the free user sees a rand number they can't act on yet, which is the strongest upgrade prompt a money app has. Household is self-serve and doubles as the decoy (6.5). **Build cost:** small. It is mostly moving `require_pro` onto the savings and insurance routes and adding a "count only" free response. Household needs shared-account data modelling, so **defer Household until after the beta** and launch with Free and Pro only.

### 6.3 Competitive context (checked 2026-10-19)

| Competitor | Price | What's included | Where Piggybank sits |
|---|---|---|---|
| [22seven](https://apple.co/2YcCbXG) (Old Mutual) | **Free** (App Store listing). Charged R25 to R70/mo until it [went free in 2014](https://businesstech.co.za/news/?p=67314) | Links 120+ SA institutions, budgeting | **Above.** Piggybank can't win on tracking alone. It must win on "finds money to cut" and on privacy (local AI) |
| [YNAB](https://getfinny.app/blog/ynab-pricing-2026) | **US$14.99/mo or US$109/yr**, 34-day trial, no free tier | Envelope budgeting, US-centric bank links | **Well below.** Estimate: US$14.99 × R18 = about R270/mo. R49 is about 18% of YNAB's price |
| Bank apps (FNB, Capitec, Discovery etc.) | Not checked | Built-in spend insights | Free and already installed. Piggybank's edge is a cross-bank view plus cutting |

22seven's own history is a warning. It charged R25 to R70/mo and then [dropped the fee because it was "an obstacle"](https://www.fin24.com/Tech/News/SA-cash-management-app-22seven-goes-free-20140902). A plain tracker at any price struggles in SA. A tracker that finds money is a different pitch.

### 6.4 Unit economics

**Variable cost per Pro user per month** (estimates unless sourced):

| Item | Arithmetic | R/user/mo |
|---|---|---|
| Penny on local Ollama | Runs on Tiaan's own host; marginal power only. Estimate | ~R0 to R1 |
| Anthropic Haiku fallback (if enabled) | [US$0.10/M in, US$0.50/M out](https://platform.claude.com/docs/en/about-claude/pricing) (from the pre-beta research). 100 chats × (3,000 in + 500 out) = US$0.03 + US$0.025 = US$0.055 × R18 | ~R1 |
| Tavily (insurance check) | Free tier 1,000 credits/mo, app cap 800 (research Q7). About 30 credits per user per month means the free tier covers about 26 users. Paid tier price: Not found | R0 up to ~26 users |
| **PayFast card fee** | [3.2% + R2.00 ex VAT](https://payfast.io/fees): 0.032 × 49 + 2 = R3.57, about R4.10 incl. VAT | R4.10 |
| **or Google Play Billing** (if required, §7) | Estimate: 15% subscription service fee, so 0.15 × 49 | R7.35 |

**Gross margin per Pro user:** PayFast route: (49 − 4.10 − 2) ÷ 49 = **88%**. Play Billing route: (49 − 7.35 − 2) ÷ 49 = **81%**. Free users cost about R0 to R1 each.

**Fixed costs** (estimates): home host power and internet share about R150/mo; Play developer account R450 once (research Q7); Apple Developer US$99/yr (about R150/mo) only once iOS ships; domain about R25/mo. **Total about R175/mo now, about R325/mo with iOS.**

**Break-even:** R175 ÷ R42.90 net per Pro user = **5 Pro users** (7 or 8 with iOS). Money isn't the constraint. Tiaan's time is.

**Target blended ARPU** across all users: R49 × 5% paid conversion = **about R2.45 per user per month**. The 5% is an estimate, a typical freemium consumer rate with no SA source found. At that rate, R5,000/mo of Pro revenue needs about 102 Pro users out of about 2,000 total.

### 6.5 Pricing psychology

1. **Anchor on savings, not on other apps.** Show "Pro found R1,240/mo · Pro costs R49/mo" on the upgrade screen, because a 25× return beats any price comparison.
2. **Decoy:** once Household exists at R79, Pro at R49 looks like the sensible choice for one person, and Household catches couples who would otherwise share one login.
3. **Annual framing:** show "R490/yr: 2 months free", not "17% off", because months are easier to grasp than percentages. Lead with monthly in the beta: testers need to feel the monthly value before they'll commit to a year.

### 6.6 Launch vs scale pricing

- **Beta (wave 1 and 2):** Pro free for everyone, as already planned. Because there are no paid-tier cohorts to protect yet, the beta is purely about the habit and "savings found".
- **First 90 days paid:** a **founding price of R29/mo, locked for 12 months**, for beta testers and the first 50 sign-ups. Because early users carry bugs, iOS gaps and bank-parser misses, a visible thank-you price keeps them. Everyone else pays R49.
- **Grandfathering:** founding users keep R29 for 12 months, then move to the price at that time with 30 days' notice. No silent increases, because trust is the product in a money app.
- **When to raise from R49 to R69** (specific triggers): (a) median "savings found" per Pro user is at least R500/mo, **and** (b) monthly Pro churn is below 6% over 3 months, **and** (c) iOS has full parity. Until all three hold, R49 stays.

---

## 7. Distribution and billing compliance

| Route | Billing | Status |
|---|---|---|
| Sideloaded APK (today, tailnet `/downloads`) | PayFast is fine | Live for Tiaan only |
| Google Play internal testing (wave 1) | Pro is free, so no billing question | Needs the R450 Play account (STATUS #10) |
| Google Play production | **Very likely Google Play Billing for subscriptions.** Google's new external-payment option starts in the US, UK and EEA on 2026-06-30, with a [global rollout set for 2027](https://www.androidheadlines.com/2026/06/google-play-store-external-billing-fee-changes.html); South Africa isn't named | **Confirm** in Google's Play Payments policy before going public. The PayFast in-app checkout may need to become Play Billing for Play users |
| Play production gate | New personal accounts need **12 testers for 14 days** (STATUS #10) | Plan wave 1 with that in mind |

**Implication:** keep PayFast for sideload and web sign-ups, plan a Play Billing integration for the Play build, and budget the fee difference (about R3/user/mo).

---

## 8. Go-to-market: from beta to the first 10 paying users

1. **Recruit 12 testers, not 3 to 5.** The Play production gate needs 12 for 14 days anyway, and 12 gives a readable signal on whether they'd pay.
2. **Where testers come from** (assumption): Tiaan's own circle, Bossie's Gym members, Fynbos clients' younger staff, and family. These are warm channels at zero cost.
3. **Collect bank samples before invites** (beta plan Phase B). Auto-capture failing on a tester's bank is the fastest way to lose them.
4. **The message:** "Find out what you're paying for every month that you forgot about." Not "AI budgeting app", because the AI is the weakest part today and "AI" plus "money" reads as risky in SA.
5. **End-of-beta pricing interview** (add to the beta plan): ask each tester (a) the savings found in their account, (b) the four price questions (at what monthly price would Pro be so cheap you'd doubt it, a bargain, getting expensive, too expensive), and (c) "Would you pay R49 this month?" Set the launch price from those answers.
6. **The first 10 payers** come from founding-price conversions of beta testers plus referrals. A referral reward of 1 month of Pro for both people costs about R0 in variable cost.
7. **Content loop (later):** an anonymised "Average Piggybank user found R___/mo" stat, shared through Fynbos's Megan channels only on Tiaan's per-post yes.

---

## 9. Risk register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Monetisation built before the product is used daily | High | High | Gate paid launch on Tiaan's 14-day streak plus his real cutter result |
| 2 | Real financial data with **no backups** | High (today) | Severe | STATUS #6 before any invite; it's already listed as the hard gate |
| 3 | POPIA: Information Officer unregistered; cross-border transfer to Anthropic (research s72 note) | Medium | High | Register (#11); keep Ollama-only and the Anthropic fallback off, or sign an operator agreement |
| 4 | Play Billing required, so the PayFast flow is rejected | Medium to high | Medium | Confirm the policy; build Play Billing before public Play launch |
| 5 | Penny gives a wrong money answer | Medium | High (trust) | Keep the Python-computed-facts pattern; de-emphasise open chat in beta |
| 6 | Bank parser misses a tester's bank | High | Medium | Collect samples before invites |
| 7 | iOS users get manual entry only | Certain | Medium | Wave 2; don't market to iPhone users before it's ready |
| 8 | Home-hosted backend: power or ISP outage (load shedding) | Medium | Medium | Uptime monitor (free tier, research Q7); consider the Fynbos VPS later |
| 9 | Tiaan's time split with Fynbos client work | High | Medium | Beta plan already assumes a few hours a week; keep sprints small |
| 10 | Free 22seven and bank apps anchor the price at R0 | High | Medium | Sell the outcome (money found), not tracking |

---

## 10. Recommended next moves

| # | Move | Owner | When |
|---|---|---|---|
| 1 | Run the cutter on real data: back-fill 3 to 6 months of CSVs, set the rent target, mark cuts, note the savings found | Tiaan | This week |
| 2 | Start the 14-day streak and log it | Tiaan | This week |
| 3 | Update STATUS.md: #32 and #78 merged; confirm #32 is deployed on the host | Claude (docs) / Tiaan (host) | Now |
| 4 | Backups + `make restore-check`; Information Officer registration | Tiaan | Before invites |
| 5 | Confirm whether Google Play's payments policy for SA requires Play Billing | Claude (research) | Before the paid launch |
| 6 | Move the line between tiers: cutter and insurance check to Pro, free shows the count and rand teaser; Penny free quota | Claude (backend + app PRs) | After beta, before the paid launch |
| 7 | Add the end-of-beta pricing interview to the beta plan | Claude (plan edit) | Before wave 1 |
| 8 | Recruit 12 testers and collect their bank samples | Tiaan | Before ~2026-11-23 (date will slip) |

---

## 11. Open questions for Tiaan

1. Is Piggybank meant to earn money, or is it a personal tool with a beta for feedback? The answer decides whether moves 5 to 7 matter at all.
2. Are you VAT-registered? This report assumes not; if you are, R49 includes R6.39 of VAT and the margins drop.
3. Does a live PayFast merchant account exist, or only sandbox?
4. Will Piggybank go to Play production, or stay sideloaded or internal-testing for the foreseeable future?
5. Is a founding price of R29/mo acceptable for Piggybank? (Fynbos's no-discount rule covers Fynbos services, not this app.)

### Answers (Tiaan, 2026-10-19)

1. **Earn money.** Moves 5 to 7 stand.
2. **Not VAT-registered.** The unit economics in §6 stand as written.
3. **No live PayFast merchant account.** Opening one becomes a prerequisite for any paid launch; until then nobody can be charged.
4. **Sideload testing only.** The Play Billing question (§7, risk 4, move 5) is parked until Play production is on the table. The 12-tester target stays for the pricing signal, not the Play gate.
5. **R29 founding price approved** (12 months locked, beta testers and the first 50 payers).

---

**Not checked:** bank-app budgeting features and prices; Google's official SA payments policy text (news only); Play's exact subscription fee for SA; Tavily paid-tier pricing; deploy state of backend #32. The [22seven current-price source](https://apple.co/2YcCbXG) is an App Store listing, not a pricing page.
