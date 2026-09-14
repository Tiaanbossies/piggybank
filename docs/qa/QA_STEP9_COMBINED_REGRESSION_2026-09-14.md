# Piggybank Combined Regression Re-Check (2026-09-14)

Step 9 task 5 of `plans/piggybank-nav-stitch-ota-update.md`: a re-verification across the screens
changed by Steps 1, 5, 6, and 8, now that all three are merged to `master` (`6165bec`), to confirm
nothing regressed once every phase's changes are combined. Baseline for comparison:
`docs/qa/QA_VISUAL_UIUX_AUDIT_2026-09-11.md`.

**Method:** static pass (`flutter analyze`, already-passing 486-test suite) + live walkthrough on
the `piggybank` Android emulator, logged in as the demo user, app at its real production build
(1.0.1+2, matching the live-published backend release).

---

## Top-line result

**No new Critical or High findings.** Every screen in scope loads, navigates, and renders
correctly. The two Step 5 dead-space fixes verified as working; the new Step 6 screen and Step 8
banner both behave correctly.

| Severity | Count | Notes |
| --- | --- | --- |
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 1 | Calculators screen still has some residual whitespace (improved, not a regression) |

---

## Step 1 — Global page transitions + tab-switch fade

Navigated all five bottom-nav tabs (Home, Invest, Budgets, Assistant, Settings) plus in-stack
pushes (Dashboard → Trends, Settings → Subscription, Dashboard → Accounts/Calculators) and back.
No crashes, no dropped frames observed, no stale content flashes. Confirmed clean.

## Step 5 — Dead-space fixes

- **Accounts:** confirmed fixed. The new "Accounts overview" stat strip (Accounts count, Average
  balance, Largest account) fills what was previously ~50-70% blank space below the account list.
  Matches the baseline's suggested fix almost exactly.
- **Calculators (Loan Calculator):** improved, not fully resolved. An icon + one-line description
  ("Work out the monthly payment for a loan") now sits above the form, closing most of the gap —
  but there's still a visible blank band between the segmented Loan Calculator/Accelerator control
  and that icon, plus space below the Calculate button on a tall viewport. **Not a regression**
  (materially better than baseline) and not Critical/High — logging as a Low, same tier as the
  original L1 finding, worth a follow-up pass but not launch-blocking.
- **Subscription:** confirmed fixed, via the intended mechanism. The diff (commit `bf59758`)
  applies a `LayoutBuilder` + `ConstrainedBox(minHeight)` + centered `Column` to vertically center
  short content instead of top-anchoring it. Live screenshot shows the "Current plan" card
  roughly vertically centered with blank space split evenly above/below, exactly matching the
  baseline's own suggested fix ("vertically centering short lists"). This is working as designed,
  not a leftover defect.

## Step 6 — New Trends screen

Loads correctly from the Dashboard's "Trends" card. Net worth chart, "Spending patterns" and
"Recurring spend" empty states all render with icon + explanatory copy — notably *better*
progressive disclosure than the Budgets screen's still-open M1 finding from the baseline audit.

One thing surfaced here: the "Budget adherence" panel shows **"Internal server error."** This is
**not a new regression** — it matches the pre-existing `budget-usage` 500 bug already tracked from
an earlier session (`piggybank-backend/backend/app/summaries/router.py:145-150`,
`MultipleResultsFound` on `scalar_one_or_none()`), which is out of scope for this blueprint and was
already carried forward as a known open issue before this session. Flagging here only to confirm
it's the same known bug, not something Steps 1/5/6/8 introduced.

## Step 8 — Tailscale domain switch + update-check banner

Verified both banner states live against the real deployed backend (build 1.0.1+2, matching the
backend's published `latest.json`):
- **No banner** when the app's own build number is current — confirmed on the real production
  build.
- **Banner shows correctly** for an older build number, with correct version text and a working
  Download link — verified separately via the three synthetic build-number scenarios (see main
  session notes), not re-repeated here since Step 9 task 3 already covered it in detail.

Dashboard renders cleanly in both states, no layout shift or clipped content from the banner
being present/absent.

---

## Confirmed clean (carried forward, still true)

Everything the baseline called out as clean remains clean — no code touched by Steps 1/5/6/8
affects tooltips, segmented-control color+checkmark pairing, bottom-nav item count, icon style, or
dark-mode contrast math.

---

## Recommended next step

Nothing here blocks Step 9 from being marked complete. The one Low finding (Calculators' residual
whitespace) can be folded into whatever future pass eventually addresses the baseline's remaining
L2-L4 polish items — no urgency.
