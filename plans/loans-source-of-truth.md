# Memo: what decides a loan's balance?

Written 2026-10-13. This is a decision memo: no code yet. Tiaan picks the options in §4, then one backend PR and one small app PR follow.

> **Decided 2026-10-13: Tiaan went with all four recommendations** (D1c, D2i, D3i, D4i). Built as [piggybank-backend#32](https://github.com/Tiaanbossies/piggybank-backend/pull/32) and [piggybank#78](https://github.com/Tiaanbossies/piggybank/pull/78).
>
> **Correction to §3's figures:** the old maths counted 30.4375-day months, so a loan started 12 calendar months ago counted only 11 instalments. The memo's "R171,674.09 now" is really the balance after 11. After 12 the balance is **R168,941.95**, and after 18 it is R151,965.64. The build counts calendar months, so the errors in §3 are each about one instalment off, but the conclusions stand.
>
> **Two build details not in §5:**
> - PATCH ignores an unchanged balance, because app 1.0.9 sends the balance back on every rename.
> - Changing a loan's original balance or start date works its anchor out again from the schedule. Changing the rate, term or instalment keeps the anchor.

## 1. The problem in one line

A loan's balance (`liabilities.outstanding_amount`) is set by **two rules that don't know about each other**:
- the **repayment schedule**, which assumes every instalment was paid;
- the **payment log**, which subtracts every payment you log.

On top of that, the schedule figure is calculated only once and then freezes.

The balance matters because net worth, the Liabilities screen, Penny's context, the savings numbers and the progress card all read it.

## 2. How it works today (backend `782fc53`, app 1.0.9+10)

| Path | What it does to the balance | Reachable from the app? |
|---|---|---|
| Create with loan details (original balance, rate, start date, term or instalment) | Sets the schedule balance **as of today**, assuming every instalment since the start date was paid (`calc_outstanding`, called from `LiabilityCreate`) | Yes ("Add liability" with loan details) |
| Create with an amount only | Stores the amount you type | Yes |
| **Log payment** | Balance = balance − principal portion. No floor, no check against the balance | Yes (loan detail → Log payment) |
| Delete payment | Balance = balance + principal portion | Yes |
| Edit (PATCH) with a loan detail changed and no balance sent | Balance = schedule balance today **minus all logged principal ever** (`router.py:192-212`) | **No.** The app's edit sheet always sends the balance and never sends loan details, so only the raw API reaches this |
| Edit with a balance | Stores the amount you type | Yes |
| Time passing | **Nothing.** There is no job that rolls the schedule forward | — |

## 3. What goes wrong (reproduced against the real backend today)

The example loan is R200,000 at 12% over 60 months, started 12 months ago. The instalment is R4,448.89. The schedule balance is R171,674.09 now, R168,941.95 at 13 months, R166,182.47 at 14, and R151,965.64 at 18.

| # | Scenario | Result | Correct | Error | Reachable from app |
|---|---|---|---|---|---|
| A | Add the loan with its details, then **log the past 12 instalments** to fill in history | R140,474.09 (test used R2,600 principal each) | R171,674.09 | **R31,200 too low.** Net worth is overstated by the same amount | **Yes** |
| B | Add the loan, log 2 instalments over 2 months, then edit the rate | B(14) − both payments ≈ **R160,690** | R166,182.47 | **~R5,490 too low**, because the schedule already counted those payments | No (API only) |
| C | Card at R1,000, log a R1,500 payment | **−R500.00** | R0 (or R500 in credit) | A negative liability **adds** R500 to net worth | **Yes** |
| D | Add the loan with its details and **log nothing** for 6 months | Stays R171,674.09 | R151,965.64 | **R19,708 too high** and growing by ~R2,700/month. Net worth is understated | **Yes** |

**D is the one that hits a daily-driver user.** Auto-capture already records the debit order as a transaction, so nobody will also open the loan and log it as a payment. The less you log, the more wrong the balance gets.

**A is the trap for anyone careful:** the app invites you to fill in the payment history, and doing so double-counts.

## 4. Decisions for Tiaan

### D1. What is the source of truth for a loan with full details?

| Option | How it works | Good | Bad |
|---|---|---|---|
| **(a) Schedule only** | Balance = schedule as of today, rolled forward nightly. The payment log becomes a record only and never moves the balance | Zero upkeep; fixes D; A can't happen | Extra or early payments are invisible; a missed instalment isn't reflected |
| **(b) Payments only** | Balance = original − Σ logged principal | Exact if you log everything | Every instalment must be logged, including the whole history for a loan added mid-term. That breaks the "under 1 min/day" goal and still fails D |
| **(c) Statement anchor + schedule** *(recommended)* | Store an **anchor**: a balance and its "as of" date, taken from a statement or from the schedule at creation. Balance = schedule rolled forward from the anchor, minus **extra** principal logged after the anchor date. Typing a new balance (for example from the latest statement) resets the anchor | Zero upkeep like (a); extra payments still count; a statement fixes any drift in one edit; A becomes impossible (payments dated before the anchor are history only) | A migration (two columns) and a nightly job; the meaning of "Log payment" changes (D2) |

Loans **without** full details (credit card, tax, "other", anything typed as just an amount) stay manual under every option. The balance is what you type, and a logged payment reduces it (with D3's floor).

### D2. What does "Log payment" mean under (c)?
- **(i) "Log extra payment"** *(recommended)*: only the amount above the instalment reduces the balance, and normal instalments are assumed. This matches what auto-capture already sees.
- (ii) Keep "Log payment" for every instalment, and have the backend work out the extra part by subtracting the scheduled instalment. This is more magic and more ways to be wrong.

### D3. Payments bigger than the balance
- **(i) Floor at R0** *(recommended)*: the payment is kept and the loan shows "Paid off".
- (ii) Reject with an error.

Either way, the balance never goes negative. This fix stands on its own and can ship before D1.

### D4. Existing data
- **(i) Flag, don't fix** *(recommended)*. The migration sets each loan's anchor to its current balance and last-updated date. It also lists loans that have payments dated **before** the loan was added (likely scenario A) on the loan screen as "check this balance against your statement".
- (ii) Recalculate silently. This is risky: real overpayments look the same as double counts.

## 5. What the build would be (once D1 to D4 are picked; assuming the recommended options)

**Backend PR:**
- **Migration:** add `anchor_balance` and `anchor_date` to `liabilities`. Backfill them from `outstanding_amount` and `updated_at`.
- **One helper,** `current_balance(liability, extra_principal_since_anchor)`, used on write, in a **nightly roll-forward job** (next to the 00:30 recurring-detection job), and by PATCH.
- **No reader changes.** The five readers of `outstanding_amount` (net-worth summary and snapshot, chatbot, `ai_context`, `context_builder`) keep reading the column, which the job keeps current.
- **Payments:** add `is_extra` (default true for new logs). Payments dated before the anchor never move the balance. Floor at R0 (D3).
- **PATCH:** a new balance resets the anchor; changed loan details recompute from the anchor rather than subtracting all payments.
- **Tests:** scenarios A to D above, the roll-forward across month boundaries, a zero-rate loan, and a loan already paid off.

**App PR:**
- The edit sheet's balance becomes "Balance on your latest statement" with an "as of" date.
- "Log payment" becomes "Log extra payment", with copy explaining that regular instalments are counted automatically.
- Show the D4 flag where it applies.

This is roughly one backend PR and one app PR. It doesn't depend on device pass 2.

## 6. Open question for Tiaan

Which loans do you have in Piggybank today (a car loan, a student loan, anything with full details entered)? Have you logged payments on any of them? That tells us whether your own net worth is currently off and in which direction (A makes it too high, D too low). Claude can't read the production database, so this needs your eyes or a quick look at the Liabilities screen.

## Related
- `STATUS.md` §3 item 5.
- The from-pattern fix (backend #31) is a separate bug and is already in review.
