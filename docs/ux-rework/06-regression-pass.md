# UX rework: on-device regression pass

Blueprint Step 9, task 3. **Any missing capability blocks the release.**

How to run it: install the `feat/ux-rework` build on your phone, sign in yourself
(Claude never enters passwords), then for each row open the new location and use the
capability once. Tick **Device** with ✓, or write what went wrong. Check once with
Settings › Accessibility › Remove animations on, for the reduced-motion rows (B4, J5).

Rows come from the spec's §9 mapping (`04-spec.md`); **Since spec** notes what Steps
6–8 added (motion, mascot moments, Undo deletes) so you check the final behaviour.
Undo deletes (Step 8) apply to: transaction, budget, goal, recurring cost, dividend,
RA and TFSA contribution. Holding, portfolio, liability payment and log out still
confirm.

Automated gate at the time of writing: `flutter analyze` clean, `flutter test` green
(698+ tests).

| Row | New location | Change | Since spec | Device |
|---|---|---|---|---|
| A1–A6 | Same routes | none |  | |
| A7 | `/onboarding` | page copy follows the new tabs |  | |
| A8 | `computeRedirect` | none; its tests must stay green |  | |
| B1 | Shell: Home · Transactions · Plan · Invest · Penny | tab set changes; Settings to the avatar |  | |
| B2, B3 | Shell | kept |  | |
| B4 | Shell | fade → fade-through, still skipped on reduced motion | Fade-through: new tab fades in from 0.92 scale. Instant with reduced motion on. | |
| C1 | Home | kept |  | |
| C2 | Home §1 | kept |  | |
| C3 | Home §2, also on the Transactions tab | kept + second placement |  | |
| C4 | Net worth card (Home §5) + Net worth screen | moved from hero to card | Net worth card grows into the Net worth screen. | |
| C5 | Hero sub-line (today) + hero (month) | restyled into the hero | Hero counts to a new value; "Quiet day so far" with Penny asleep when nothing spent today. | |
| C6 | Home §4 → Plan › Savings | target changes to the Plan segment | Shows "target met this month" with Penny when the gap is closed. | |
| C7 | Home §6 Needs attention | skips completed goals; tappable |  | |
| C8 | Transactions › Insights; Plan › Budgets "See trends" | card removed from Home |  | |
| C9 | Net worth screen rows | quick links removed from Home |  | |
| C10 | Home §7 → Transactions tab | "See all" switches tab |  | |
| C11 | Home FAB | kept |  | |
| C12 | — | **removed** (dead placeholder; DESIGN.md change 2) |  | |
| D1, D2, D2a | Net worth → Accounts | Accounts' app-bar icon now switches to the Transactions tab | Account row grows into Account detail. | |
| D3 | **Transactions tab** | becomes a tab root | Empty (no filter): "No transactions yet." with Penny welcoming. | |
| D4 | Home FAB, Transactions FAB/row | unchanged sheet | Delete in the sheet: no dialog; row hides, Undo for 4 s. Saved row tints after save. | |
| D5 | Net worth → Assets | — |  | |
| D6 | Net worth → Liabilities | — |  | |
| D7 | Transactions ⋮ Expenses summary | app-bar icon → overflow |  | |
| D8 | Transactions › Insights; Plan › Budgets link | — |  | |
| D9 | Net worth → Loan calculators | — |  | |
| D10 | Home banner; Transactions › Review; Settings › Data sources › Review | Review entry always visible on Transactions when pending > 0 |  | |
| D11 | Transactions ⋮ Import | — |  | |
| E1 | Plan segments (Budgets · Goals · Savings) | third segment added |  | |
| E2 | Plan › Budgets | month switcher in the app bar; resets to the current month |  | |
| E3 | Plan › Goals | in-progress first; Completed (n) group |  | |
| F1 | Plan › Savings (Home card shortcut) | Settings row removed |  | |
| F2, F3 | Plan › Savings | same; deletes get undo |  | |
| F4 | Plan › Savings chip → Penny tab | same `go('/assistant')` |  | |
| F5, F6 | Plan › Savings › cost › Policy check | — |  | |
| G1–G6, G2a | Invest | skeleton + Retry; Compare labelled |  | |
| H1 | Penny tab (`/assistant`) | data-aware chips; thinking mascot; "analyse" |  | |
| I1 | Settings (avatar) › Profile | Settings is now a pushed route |  | |
| I3 | Settings › Account › Privacy & consent | regrouped |  | |
| I4 | Settings › Account › Subscription | regrouped |  | |
| I5 | Plan › Savings | **row removed**; capability now in its home |  | |
| I6 | Transactions ⋮ Import history | moved next to Import |  | |
| I7 | Settings › Preferences › Appearance | regrouped |  | |
| I8, I8a | Settings › Account › Security (+ `/settings/data-export`) | route kept |  | |
| I9 | Settings › Preferences › Notifications | regrouped |  | |
| I10 | Settings › Data sources › Bank notifications & email | renamed |  | |
| I11 | Settings › About | — |  | |
| I12 | Settings › Log out | now confirms (N8) |  | |
| J1–J3, J6–J8 | Shared | kept |  | |
| J4 | Undo snackbars | extended to deletes (§5) |  | |
| J5 | `context.reducedMotion` | now gates every motion in §3 |  | |

## Result

- **On-device pass confirmed by Tiaan, 2026-10-09.** (Recorded as Tiaan's confirmation
  of the whole sheet; Claude did not verify rows individually.)
- Missing or broken: none reported
- Re-critique score (impeccable, five tab roots, light and dark, 2026-10-09): **27/40**
  (was 21/40, then 25/40). Under the ≥ 32 target: the gap is visual (contrast, flat
  hierarchy, static/empty surfaces, app-bar consistency), which the visual rework epic
  (`docs/visual-rework/`) takes on, with 27 as its baseline. Run on sample data with real
  fonts (`test/goldens/`), not a signed-in device.
