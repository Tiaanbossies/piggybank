# Piggybank: founder + pricing review (2026-10-19)

**Verdict:** Don't charge yet. Paywall guards wrong thing. Prove Tiaan uses it first.

Sources: STATUS.md (2026-10-13), plans/, `gh` checked today. GUESS = not verified.

## Problem (validate-idea)
- Real pain for Tiaan: rent gap, recurring costs. n = 1.
- n = 1 not even proven: streak unmeasured, 0/6 cost-cutting boxes (STATUS §2).
- Nobody else asked yet. Beta wave 1 = first real test.
- Who else, GUESS: young SA earners, Android, debit orders bleeding money.

## MVP cut (mvp-scope)
- Keep: auto-capture, one-tap review, savings gap, recurring-cost cutter.
- Park for beta: TFSA, RA, portfolios, net-worth hub, calculators.
- Penny = nice, not core. qwen 3B on shared GPU. Don't sell it.
- Hard gates before invites: backups + restore-check, device pass 2 (STATUS §3 #1, #6).

## Price (pricing-strategy)
- Today: Free vs Pro **R49/mo**, PayFast monthly (`config.py` `subscription_price_zar`).
- Free = 3 accounts, 1 portfolio, no AI. Pro = unlimited + AI (`limits.py`).
- **Problem:** money value is free. Savings, detection, CSV import: no tier gate.
- Pro sells weakest feature (3B chatbot). Users won't pay for that.
- Cost floor ~R0/user/mo now (Ollama local, Tavily free tier) (research Q7).
- PayFast fee ~R3–4 per R49 charge. GUESS, check rates.
- **Fix:** value metric = "savings found". Pro should own the cutter + insurance check.
- Free keeps: capture, budgets, 3 accounts. Hook stays free.
- R49 fine as start. If Pro finds R300+/mo, R49 is easy yes.
- Option: 30-day Pro reverse trial on signup, then drop to Free.
- Beta plan already says Pro free + ask "would you pay" (beta plan). Good. Keep.
- Ask 4 price questions at end of beta: too cheap / cheap / pricey / too pricey.

## GTM (go-to-market)
- Wave 1: 3–5 F&F, Android, ~2026-11-23 (date will slip, plan paused).
- Play internal track = fine for 3–5. Public prod needs 12 testers × 14 days (STATUS §3 #10).
- So: recruit 12, not 5. Serves Play gate + more pay signal.
- First 10 payers, GUESS: Bossie's Gym members, Fynbos network, family.
- Hook line: "Find R___ a month you're wasting." Not "AI budget app".
- Competes with free bank apps + 22seven (GUESS, check). Must beat on cutting, not tracking.

## Risks
- Building paywall before Tiaan is a daily user. Biggest risk.
- Real money data, no backups yet (STATUS §3 #6). Blocks everything.
- POPIA: Information Officer unregistered; Anthropic cross-border (research Q6).
- PayFast prod not set up: sandbox creds default (`config.py`). GUESS: no merchant account.
- iOS = manual mode only. Halves appeal for iPhone users.
- Side project, few hrs/week. Fynbos revenue comes first.

## Next 3 moves
1. Tiaan: back-fill CSVs, set rent target, run cutter for real. Log savings found.
2. Before beta: move savings cutter + insurance check behind Pro (all free in beta anyway).
3. End of wave 1: 4 price questions + "savings found" per tester. Then set the price.

State note: STATUS.md says backend #32 / app #78 open. `gh` says both **merged** 2026-10-13. Update STATUS.
