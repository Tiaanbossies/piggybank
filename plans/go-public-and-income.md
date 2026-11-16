# Piggybank: go public and start earning

> **Written 2026-11-16** by Alex (offer and growth) for Tiaan. Advisory only: no code, deploy, send or tester-facing wording here. Status: D15 to D20 approved by Tiaan on 2026-11-16; no step started.

**Inputs:** `STATUS.md`, `docs/REVIEW-2026-11-05.md`, `reviews/2026-10-24-founder-pricing-full.md` (called "pricing review" below), `plans/founder-review-fixes.md`, `../piggybank-backend/docs/CAPACITY-2026-11.md` (fixes F1 to F14).

**How to read the numbers:** a figure with a source is cited. Everything else is marked **assumption**. No Piggybank funnel number exists yet, because nobody outside Tiaan has used the app.

---

## 1. Bottleneck

Nobody outside Tiaan has installed Piggybank, so the constraint is getting the first 12 testers to a confirmed recurring cost, and two things block even inviting them: no backups (F1) and an APK that only downloads inside the tailnet (REVIEW §3).

Price, Pro features, Play Billing and server size are not the constraint yet. The capacity audit says the box carries a free beta of 50 once F1 to F6 are done.

## 2. Recommendation

### 2.1 What this can earn, honestly

Unit figures from the pricing review §6.4: Play takes 15%, variable cost about R2 per Pro user per month (estimate), so Pro nets **R39.65** at R49 and **R22.65** at the R29 founding price. Planning conversion is **2%** of accounts (RevenueCat 2026 median; range 1 to 3%).

| Stage | Accounts | Pro at 2% | Net from Pro / month | Fixed / month | Left / month |
|---|---|---|---|---|---|
| Beta | 50 | 0 (Pro is free) | R0 | R175 (estimate, pricing review) | −R175 |
| Paid launch | 500 | 10, all founding | 10 × R22.65 = R227 | R175 + R229 VPS (F9) = R404 | **−R177** |
| 12 months | 5,000 | 100: 50 founding, 50 at R49 | 50 × R22.65 + 50 × R39.65 = R3,115 | R404 | **about R2,700** |

At one evening a week (about 17 hours a month, **assumption**), R2,700 is roughly **R160 per evening hour**, and only if 5,000 accounts arrive. No channel in this plan has data that says they will. For scale: one Fynbos build is R1,200 once plus a R349/mo Seed retainer.

So the recommendation is in three parts:

1. **Treat Piggybank as a 12-month proof, not this year's income.** Cap it at one evening a week (D15) so it does not eat the Fynbos sales hours, which pay sooner.
2. **The lever is conversion, not price.** At 5% instead of 2%, the 5,000-account row roughly triples (250 Pro: 50 × R22.65 + 200 × R39.65 − R404 = about R8,650). A tester who sees "R1,240/mo found" pays; one who sees a budget app does not (pricing review §4.2 Q1). Every hour goes to activation until the beta numbers exist.
3. **5,000 is a capacity target, not a forecast.** Judge the channels only after about 100 invitations (volume before verdict).

### 2.2 The offer

One offer, one buyer, one channel until 50 people pay.

- **Buyer:** salaried Android user, 22 to 35, two or more bank products, five or more debit orders ("Thandi", pricing review §4.5; a hypothesis until the interviews).
- **Promise:** every debit order and subscription on all your accounts in one list, with where to stop each one, inside the 60-day dispute window (PASA, 13 April 2026). Never promise a reversal: PASA says reversals are not guaranteed.
- **Not the promise:** "AI budgeting app". Bank apps budget for free and stop debit orders for free (pricing review §6.3).

| | Free | Pro |
|---|---|---|
| Auto-capture, one-tap review, CSV import (3 months) | Yes | Unlimited history |
| Accounts | 3 | Unlimited |
| Recurring costs | Count and rand total only | Full list, cut tracking, "savings found", still-charged alerts |
| New-debit-order alert | Yes | Plus the 60-day countdown and the bank's stop steps |
| Insurance check | No | Up to 5 policies |
| Penny | No | Yes, rate-limited |

This is the pricing review's §6.2 target with one change: **no free Penny questions** (D20). Penny runs on one 4 GB GPU, and about 15 AI calls in flight stall the whole API (capacity audit). Keeping Penny Pro-only means AI load scales with payers (about 100 at 5,000 accounts), not with accounts. Penny is a bonus in the offer, not the headline.

This line is **not built**: today the cutter is free and every account is Pro until 28 Feb 2027. Moving it is "after the beta, before paid launch" (pricing review §10 move 8).

**What Pro must have working before anyone is charged:** the cross-bank recurring list for the tester's own banks, cut tracking with a running "savings found" total, the where-to-stop-it steps, and Play Billing. If a payer's bank is not parsed, there is no product for them.

### 2.3 Price

All decided already (STATUS item 17), no change proposed:

- **R49/mo** base plan, through Google Play Billing.
- **R29/mo founding price for 12 months**, for beta testers and the first 50 payers. The cap of 50 is real, so it may be stated. Nothing else about scarcity or deadlines is used.
- No annual plan at launch: one price is easier to test, and this region leans monthly (pricing review §6.1). Revisit after 50 payers (D20).
- No discount, free month or voucher beyond the founding price. Raise R49 only on the three conditions in pricing review §6.6.

**Guarantee:** none on outcomes ("we'll find you R500" is not ours to promise). What is already true and may be said: cancel any time in Google Play, and your data exports and deletes on request.

### 2.4 Money model

| Step | What | State |
|---|---|---|
| Attraction | Free tier: capture plus the rand total of recurring costs | Built, but currently gives everything away |
| Core | Pro at R49 (R29 founding) | Priced, billing not built |
| Continuity | The same subscription; value shown monthly as "savings found" | Not built |
| Later, not now | Household tier at R79 (pricing review §6.2) | Deferred to 100 Pro users |

Break-even on fixed costs is 5 Pro users at R49 or 8 at R29 before the VPS (pricing review §6.4), and **18 founding users** once the R229 VPS is added (R404 ÷ R22.65). At 2% that is about 900 accounts. So the paid launch at 500 accounts runs at a small loss; that is acceptable, and it is why F9 should not be bought earlier than the paid launch needs it.

### 2.5 Leads: the first 50

Channel: warm network, one person at a time. Cash cost R0.

- **Lead magnet: the 20-minute debit-order audit** (pricing review §4.4 experiment 2). The tester imports three months of statements, Tiaan sits with them, they leave with a rand total. It is also the interview and the activation step, so one sitting does three jobs.
- **Maths (assumption):** if half of the people invited install, 50 testers needs about 100 invitations. Inside one evening a week, about 4 sittings or 8 invitations a week is realistic, so **50 testers lands around February or March 2027**, not November. The first 12 matter more than the 50: they are also Google's 12-tester gate.
- **Order:** the 20-name list (pricing review §8.2), pick the 12 with two or more banks and exclude polite close family for interviews; each tester is asked for one introduction at the end of the sitting.
- **Run wave 1 as a Play closed test, not a sideload** (D16). It removes the tailnet download blocker, starts the 14-day clock for the 12 testers, and avoids the 2027 sideload friction. It needs the Play developer account: US$25 once, about R450 (STATUS item 10).

### 2.6 Leads: the first 500

Only after the wave-1 numbers pass the gate in §2.8. Still one channel at a time: more of what worked, then better, then new.

1. **Play listing** worded on the promise in §2.2. This is the conversion page for everything below.
2. **One useful guide**, "how to find every debit order on your statement, and the 60-day rule", citing PASA. Posted where the question is already asked (r/PersonalFinanceZA, about 43,000 members in May 2025, pricing review §8.2), under that community's rules, as help and not as an advert.
3. **A "found R___/mo" share card** from the app. It is the only loop candidate (pricing review §4.2 Q3). Build it only if testers say they would share it.
4. **Referral ask with no reward** (D18): an introduction, not a free month. The pricing review proposed a free month for both people; that discounts a R29 product that nets R22.65, and nobody has paid yet.

Not now: paid ads (no conversion data, and an account is worth about R0.98 a month at 2%, pricing review §6.4), Product Hunt, X, iOS.

**500 accounts needs a channel that is not Tiaan's evenings.** If the guide and the listing bring fewer than about 20 installs a week a month after launch (**assumption** for the threshold), drop the 5,000 target rather than chase it with hours.

### 2.7 Retention

| Moment | Risk | What to have in place |
|---|---|---|
| Day 1 to 2 | Notification access never granted, or the bank is not parsed, so the queue is empty | Fixture per tester's bank before the invite (fixes plan PR 3 item 6); the listener-state banner (G3); check each tester's first capture by hand |
| Day 7 | Saw the list, cut nothing | The one beta test: a cost marked "cut" within 7 days (pricing review §5) |
| Week 3 | Stops opening it | New-debit-order alert as the reason to return; week-3 retention target 60% |
| 28 Feb 2027 | Free Pro ends before paid Pro can be bought, so testers lose features with no way to keep them | D17: move the date if Play production is not approved in time; tell testers in the app at least 30 days ahead |
| Monthly, once paid | "What am I paying for?" | A monthly "savings found so far" total against the R49 |
| Cancel | Bad reviews from a hard exit | Cancel stays one tap in Play; data export works; ask one question on why |

There is no email channel (SMTP is unset), so every one of these has to happen in the app or in person. That is fine for 50 and a gap at 500.

### 2.8 Gate before charging anyone (D19)

Turn on paid Pro only when all of these hold. Targets are the pricing review §8.4 day-60 figures:

- 12 or more testers active for 14 days on the Play closed test
- Activation 60% or more (a recurring cost confirmed within 7 days)
- Median savings found R150/mo or more per active tester
- 30% or more of interviewed testers accept the R29 commitment question
- Capacity fixes F7 to F10 done, and the Free/Pro line moved

If activation passes but pay intent fails, change what Pro contains, not the price. If activation fails, fix capture per bank and invite nobody new.

### 2.9 Next steps, in order

Hours are **assumptions**. "T" is Tiaan's to do; "C" is a Claude session on Tiaan's go.

| # | Step | Who | Hours | Gate it clears |
|---|---|---|---|---|
| 1 | Backups, `make restore-check`, UptimeRobot monitor (F1, F2) | T | 2 | Blocks every invite |
| 2 | Open the Play developer account; register the Information Officer | T | 1 + waiting | Closed test; POPIA |
| 3 | F3 to F5: gate `/api/ai/insights`, cap concurrent Ollama calls, real client IPs | C, T deploys | 4 | AI cannot stall the API |
| 4 | F6: five-concurrent Penny test on the server | T | 1 | Decides whether F14 is ever needed |
| 5 | Wave-1 launch criteria left in REVIEW §3 (device pass 2, same-evening backend and 1.0.11) | T + C | 4 | Wave 1 |
| 6 | Upload to a Play closed test; invite the first 5 with an audit sitting each | T | 4 | First outside users |
| 7 | Weekly: 4 sittings, the five metrics from pricing review §8.4, 15 minutes | T | 4 / week | The §2.8 gate |
| 8 | At 12 testers × 14 days: read the gate. Pass → 9. Fail → fix and repeat 7 | T | 1 | Go or no-go on paid |
| 9 | Move the Free/Pro line; build Play Billing with the R29 introductory phase | C | 12 to 16 | Paid launch |
| 10 | F7 to F10, including the VPS move (R229/mo) | C, T deploys | 8 | 500 accounts |
| 11 | Apply for Play production; decide the promo end date (D17) | T | 1 + about 3 weeks' review | Public listing |
| 12 | Publish the guide; turn on paid Pro for testers at R29 | T | 3 | First rand |

Steps 1 to 6 are about 16 hours: four weeks at one evening a week, so the first outside testers arrive around mid-December 2026, not 23 November. Steps 9 to 11 are about 25 hours plus Google's review, which puts the paid launch in March or April 2027 at this pace. Starting the closed test by early February (STATUS item 10) still holds.

## 3. Decisions for you

All six approved on 2026-11-16 (`01_Company/Strategy/alex/decision-log.md`).

| # | Decision | My recommendation |
|---|---|---|
| D15 | Hours for Piggybank | One evening a week until the §2.8 gate is read; Fynbos sales keeps the rest |
| D16 | Wave 1 on a Play closed test instead of a sideload (about R450 once) | Yes |
| D17 | Free Pro ends 28 Feb 2027 | Keep the date only if paid Pro is purchasable by then; otherwise move it to paid-launch day, with 30 days' notice in the app |
| D18 | Referral reward | None; ask for an introduction only, until 50 people pay |
| D19 | Gate for turning on paid Pro (§2.8) | Adopt as written |
| D20 | Free/Pro line at paid launch: pricing review §6.2, but Penny Pro-only and no annual plan yet | Yes |

Still open from the capacity audit, and not Alex's to settle: whether "No Anthropic API key, ever" covers the product, and POPIA consent for a hosted model. Neither matters unless step 4 fails.

## 4. Brief for the invitations

Tiaan invites people he knows, in his own words; nothing is drafted here.

- **Who:** the 12 from the 20-name list with two or more banks.
- **Goal of the message:** book a 20-minute sitting, not "try my app".
- **May use:** the audit itself; the R29 founding price for 12 months for testers and the first 50 payers; Pro free during the beta; data stays in South Africa.
- **Avoid:** any promised saving or reversal; "AI"; a deadline; a referral reward (D18 is open).

## 5. Sources

Alex frameworks: Value Equation (1), trim and stack (2), true-only scarcity (6), pricing and grandfathering (7), warm outreach (8), lead magnets (9), More/Better/New (11), referrals (12), money model (13), retention cliffs (18), gross profit per hour (19), one constraint (20).

**Not checked:** whether Play's 15% includes SA VAT; the exact Play mechanism for a 12-month introductory price; current Vault22 prices; the R18/US$ rate; every hours figure above.
