# Piggybank: founder + pricing review, update (2026-10-24)

**Verdict:** still don't charge. n = 1 not proven. Banks already stop debit orders for free, so sell *finding* them across banks. Plan on ~2% paying, not 5%. One decision blocks: sideload or Play.

Full report, sources and arithmetic: `reviews/2026-10-24-founder-pricing-full.md`. Builds on the 10-19 review.

## What changed since 10-19
- Backend #32 **is deployed** (host `f3112be` contains it; same `backend/` as `main`). App now 1.0.10+11.
- Every new sign-up gets **Pro, no end date** (`deps.py` promo).
- 10-21 plan: **Play Billing from Jan**, in-app PayFast removed, Pro free until **28 Feb 2027**. Conflicts with 10-19 answer "sideload only".
- No movement on streak or the 6 acceptance boxes. Backups still not installed.

## Problem (validate-idea)
- Pain real: 36% of South Africans expect to miss a bill (TransUnion, late 2025); 39% in Q2 2026 (press report).
- Not proven: "forgotten" costs. No SA data found. 34% already cancel subscriptions themselves.
- Scorecard **20/35**. Weakest: willingness to pay (2), distribution (2).
- Timing hook: debit-order dispute window cut **365 → 60 days** from 13 Apr 2026 (PASA).
- Primary persona: Thandi, 27, Joburg, Capitec + FNB, 5+ debit orders. Hypothesis until interviews.

## Competitors (competitor-matrix)
- FNB, Standard Bank, Nedbank: stop or reverse debit orders **in their own app**; Absa: reverse. FNB and Nedbank budgeting tools free.
- Discovery: suspends card subscriptions per card.
- **No SA bank app shows other banks.** Gap = every recurring cost, every account, one list.
- Biggest threat: **Vault22** (was 22seven, Old Mutual shareholder), aggregates, paid tiers, ZAR prices not found.

## MVP (mvp-scope)
- Must: CSV import, recurring detection across banks, savings gap + "found" total, auto-capture, feedback button.
- New should-haves: **"where to stop it" link per bank**, **new-debit-order alert with 60-day countdown**.
- Park: Penny chat, TFSA/RA/portfolios, Household, iOS.

## Price (pricing-strategy)
- Keep **R49/mo**, **R490/yr**, **R29 founding** for 12 months. Same *proposed* Free/Pro line as 10-19 (not built yet).
- Free: count + rand total + new-debit-order alert. Pro: full list, cut tracking, countdown + stop steps, insurance, Penny.
- Fees at R49: Play **R7.35** · Payfast R4.10 · Paystack R2.78 · Play user-choice + Payfast ~R9.49 (worst).
- Margin: Play 81%, Payfast 88%. Break-even still **5 Pro users** (8 at R29).
- Conversion: RevenueCat 2026 median **2.0%** download-to-paid. R5,000/mo needs ~5,100 users (was ~2,000).

## Distribution
- Play Billing **required** for in-app subscriptions on Play. SA eligible for user choice billing, but it costs more here. ZAR payouts supported.
- Sideloading meets Android developer verification "in 2027".
- **Recommend:** wave 1 as Play closed test (also clears 12 testers × 14 days), Play Billing for paid. Needs Tiaan's yes.
- App uses notification access, **no SMS permission**, so Play's SMS policy doesn't apply.

## GTM (go-to-market, user-interviews, metrics-dashboard)
- 12 testers from warm network. Then r/PersonalFinanceZA (~43k members) with a useful guide, not an ad.
- Message: "Find every debit order on all your accounts, before your 60 days run out." Never promise a reversal.
- 25-minute Mom Test script in full report §8.3, ending with the R29 commitment test.
- 5 weekly metrics: activation, week-3 retention, auto-capture share, savings found, pay intent.

## Risks (new since 10-19)
- Distribution undecided. Conversion ~2%. Banks stop debit orders free. Vault22 adds detection.
- 2027 developer verification. Play may question notification-listener use.
- Still: no backups, POPIA (Information Officer, s18 notice, s72 basis for Anthropic/Tavily).

## Next 3 moves
1. Tiaan: run the cutter on real data, start the 14-day streak.
2. Tiaan: decide sideload vs Play closed test + Play Billing.
3. Then: backups + Information Officer; Claude lands 10-21 PR 1 and adds the two new beta features.
