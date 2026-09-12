# Animation improvement plans — Piggybank (Flutter)

Generated from the `find-animation-opportunities` sweep of the Piggybank app (2026-09-11), then
turned into self-contained implementation plans by `improve-animations`. Stamped at commit
`8a264ab`. No shared motion-tokens file existed before this set — plan 001 creates
`lib/core/theme/app_motion.dart`, which every other plan here imports.

## Plans

| # | Title | Severity | Status |
| --- | --- | --- | --- |
| [001](001-async-state-crossfade.md) | Crossfade loading/data/empty states | HIGH | TODO |
| [002](002-lock-screen-wrong-pin-shake.md) | Shake the PIN boxes on a wrong PIN | HIGH | TODO |
| [003](003-progress-card-value-transition.md) | Animate ProgressCard's bar value | MEDIUM | TODO |
| [004](004-chat-bubble-entrance.md) | Entrance animation for new chat bubbles | MEDIUM | TODO |
| [005](005-login-error-entrance.md) | Grow-in the login error message | LOW | TODO |
| [006](006-delete-exit-animation.md) | Delete-row exit animation | N/A | RETIRED — see plan for why |

## Recommended execution order

1. **001 first, always.** It creates `lib/core/theme/app_motion.dart` — plans 002-005 all import
   `AppMotion` and will fail to compile if it doesn't exist yet. It's also the highest-leverage fix
   (systemic, low-risk) and should land regardless of which others get picked up.
2. **002** (lock-screen shake) — independent of 001's actual edits, only needs the tokens file to
   exist. Next-highest conviction per the source audit.
3. **003** (ProgressCard value transition) — independent otherwise; do verify plan 001 isn't
   mid-flight on `dashboard_screen.dart`/`goals_screen.dart`/`budgets_screen.dart` at the same time,
   since those files are shared touch points (001 edits the screens; 003 edits the shared
   `ProgressCard` widget those screens render — no direct line conflict, but land 001 first to avoid
   reviewing two diffs against a moving target).
4. **004** (chat bubble entrance) — fully independent of the others besides the `AppMotion` import.
5. **005** (login error entrance) — fully independent, lowest severity, smallest diff.
6. **006 is retired** — no execution needed. Kept in the set as a record of why the original
   finding didn't survive closer inspection (see the plan file).

## Dependencies

- Every plan 002-005 depends on **001** having created `lib/core/theme/app_motion.dart` first.
- No other cross-plan dependencies. 001, 003, and the empty-state keying in 001 both touch
  `goals_screen.dart`/`budgets_screen.dart` — if executing out of order, re-read the current file
  state before applying either plan's steps (per each plan's own "if drift, stop" boundary).

## Not covered by this set

The audit that produced these plans explicitly rejected: animating the net-worth figure
(`HeroMetricCard`) and the portfolio allocation donut chart (both are financial data the user reads,
not decoration candidates), any change to the bottom nav tab switching (too high-frequency to ever
animate), and Material's own default dialog/switch transitions (already correct). Plan 001 also
explicitly does not extend its crossfade pattern to the ~33 other `AsyncValue.when()` call sites
found elsewhere in the app (Accounts, Transactions, Portfolios, RA, TFSA, Liabilities, Settings,
Imports, Insights, Expenses) — those were outside the audited finding's scope; treat them as a
separate future sweep if wanted.
