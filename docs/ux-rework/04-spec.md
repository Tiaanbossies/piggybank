# UX rework 04: spec

Session 2 of the UX rework epic, written 2026-10-09. **Status: approved by Tiaan
2026-10-09 (A1–A6 yes).** Session 3's blueprint is `plans/ux-rework-blueprint.md`.

Inputs: `01-principles.md` (IDs K, N, Y, T, H, P), `02-audit.md` (findings 1–8, the
7 decisions), `03-capability-inventory.md` (rows A1–J8, the regression contract).

## Decisions taken (Tiaan, 2026-10-09)

| # | Decision | Choice |
|---|---|---|
| D3 | Tab set | **Home · Transactions · Plan · Invest · Penny.** Settings opens from the top-left avatar. |
| D1 | Home hero | **"Left to spend this month"** with Spent today under it. Net worth becomes a smaller card. |
| M | Motion | **Expressive:** functional Material motion plus mascot moments. Still no confetti, streaks or badges. |

The other four audit decisions are proposed below with a recommendation and are part
of what you approve:

| # | Proposal |
|---|---|
| S | **Savings plan** becomes the third segment of the Plan tab: Budgets · Goals · Savings. Policy stays one level under a cost. |
| H | **What leaves Home:** the 4 quick links and the Trends card. Their screens move to a new Net worth screen, Transactions and Plan. |
| HP | **One header pattern** for every tab root: avatar (→ Settings) · title · up to 2 labelled actions. **The bell is removed.** |
| G | **Goals:** stays a Plan segment; in-progress goals first, completed goals folded into a "Completed (n)" group. |
| ST | **Settings scope:** account, preferences and data sources only. Savings plan and Import history move out. |

## Guardrails this spec holds to

- Presentation layer only. No backend, provider-contract, repository, model,
  detection/consent, auth, OTA or release-config change. New *derived* values (Left to
  spend, data-aware Penny chips) are computed in widgets or new UI-only providers from
  existing providers.
- No capability lost: every row in 03 maps to a place in the table at the end.
- No new state-management or routing library. go_router and Riverpod stay.
- No dark patterns: see the hook check. No guilt copy, fake urgency or punishing
  streaks; badges count real pending work only.
- No paid image generation. Mascot moments use the 5 existing assets in `assets/`.

---

## 1. Information architecture

### 1.1 Tabs

| Tab | Route | Root screen | Answers | Why it earns a tab (Q9) |
|---|---|---|---|---|
| **Home** | `/` | `DashboardScreen` (reworked) | "Am I OK today and this month?" | Opened daily (H2, T13) |
| **Transactions** | `/transactions` | `TransactionsScreen` (now a tab root) | "What did I spend, and is it right?" | The most-used list (Y15, T9). Fixes audit finding 1. |
| **Plan** | `/plan` | new `PlanScreen` host: Budgets · Goals · Savings | "Am I on track for the month and my targets?" | Weekly; groups three forward-looking features (Y12, N5) |
| **Invest** | `/invest` | `InvestScreen` | "How are my investments?" | Unchanged |
| **Penny** | `/assistant` (path kept so F4 keeps working) | `ChatbotScreen` | "Ask anything" | The differentiator. Also reached contextually (F4, F6, chips). |

**Settings** leaves the bar. It opens from the avatar on every tab root as a full-screen
route above the shell (`/settings`, root navigator, back arrow, no bottom bar). That
turns a dead affordance (audit finding 3) into the convention used by Monzo, Revolut and
most Material apps (Y1, K4), and keeps a rare destination out of the daily path without
hiding it (P2: the avatar is visible on every tab).

Plan's segments take a query parameter (`/plan?s=budgets|goals|savings`) so Home's cards
can deep-link to a segment. The default is Budgets; the last segment is kept for the
session (B2 behaviour).

### 1.2 Navigation rules

1. **One header pattern** on every tab root: avatar (48 dp target, opens Settings) ·
   title · at most 2 actions, each with an icon **and** a tooltip, or a text label where
   the icon isn't self-evident (K1, N1). No bell.
2. **Pushed screens** get back arrow + title, and stay inside the tab they came from
   (B2). The bottom bar highlights that tab (K6).
3. **Re-tap the active tab** pops to its root (B3, kept).
4. **A feature lives in one home.** A second entry point is a *shortcut* that lands in
   that home, never a second copy (audit finding 6). Shortcuts are listed in §6.
5. **FAB clearance:** every scrollable that sits under a FAB gets ≥ 88 dp bottom padding,
   with a widget test that the last row is hittable (audit finding 7, P3).
6. **Errors:** every full-screen load uses the shared skeleton → content → `InlineError`
   with Retry. No bare spinners, no dead-end text (audit finding 8, N8, Y5).

---

## 2. Screens

### 2.1 Home

Fixed order, still no customisation (`piggybank-production-completion.md` lock kept):

| # | Section | Shows when | Tap → |
|---|---|---|---|
| 1 | OTA update banner (C2) | an update exists | external APK link / dismiss |
| 2 | Review banner (C3): "4 new to review" | pending > 0 | Pending review |
| 3 | **Hero: Left to spend · {Month}** | always | Plan › Budgets |
| 4 | Savings card (C6): "Rent: gap R 3 967 · 87%" / "Set a savings target" | always | Plan › Savings |
| 5 | Net worth card: value + trend pill | always | **Net worth** screen (new) |
| 6 | Needs attention (C7): one row, the most at-risk budget, else the first *in-progress* goal | something qualifies | that budget's edit sheet / Plan › Goals |
| 7 | Recent transactions (C10): 5 dated rows, "See all" | always | Transactions tab |
| — | **Add** FAB (C11) | always | transaction sheet |

Down from 11 sections to 7, two of them conditional (T13, Y2, Y14).

**Hero states.** All values come from `currentMonthBudgetProgressProvider` (top-level
budgets only, `parentBudgetId == null`) and the existing today-spend provider.

| State | Big number | Line under it |
|---|---|---|
| Budgets exist, under | "R 4 210" left to spend | "Spent today R 186 · 22 days left" |
| Budgets exist, over | "Over by R 640" (red: over-budget is red's reserved use) | "Spent today R 186 · 22 days left" |
| No budgets | "R 2 148" spent this month | "Set a monthly budget ›", which opens the add-budget sheet |
| Loading / error | skeleton / `InlineError` + Retry | — |

The copy is factual, never judging: "Over by R 640", not "You overspent!" (guardrails).

**Net worth screen (new, pushed from Home).** It's a hub, not a new feature: the net
worth hero with its trend pill, then three rows with totals, Accounts (D1), Assets (D5)
and Liabilities (D6), then "Loan calculators" (D9) under Liabilities, where loans live
(N2 mapping). It keeps every quick-link destination 1 tap further from Home (now 2),
which is right for weekly-or-rarer screens (Y15).

### 2.2 Transactions (tab root)

- App bar: avatar · "Transactions" · **Review** (icon + count badge, real pending items
  only; hidden at 0) · **Insights** (→ Trends, D8) · overflow ⋮: Expenses summary (D7),
  Import CSV / Scan receipt (D11), Import history (I6).
- Body unchanged: type chips, Filter sheet, grouped-by-day list, Load more, pull to
  refresh, tap row → edit sheet. A review banner sits at the top when pending > 0, the
  same component as Home's.
- **Add transaction** FAB opens the shared sheet (D4).
- Import and its history now live together (inventory observation 7).

### 2.3 Plan (tab root)

- App bar: avatar · "Plan" · on Budgets, the month switcher (chevrons) moves into the
  app bar's bottom so it stops competing with the segment control.
- Segmented control: **Budgets · Goals · Savings**. The FAB follows the segment: Add
  budget / Add goal / Add cost.
- **Budgets** (E2): unchanged, plus a "See trends ›" link at the end of the list (second
  route to D8). Opens on the current month every time the tab is entered in a new month.
- **Goals** (E3): in-progress goals first, sorted by target date. Completed goals fold
  into "Completed (n)", collapsed by default (Y8). Same edit/add sheets.
- **Savings** (F1–F4): the Savings plan body, moved as-is: target card, suggestions with
  undo, recurring costs, "Where should I cut? Ask Penny" chip. The cost row's **Policy
  check** button opens Policy (F5/F6), now depth 2 from the Plan tab.

### 2.4 Invest

Content unchanged (G1–G6). Fixes only:
- Skeleton while loading; `InlineError(onRetry:)` for both error branches
  (`invest_screen.dart:57`, `:132`).
- **Compare** shown as an icon + text button, or at minimum an icon with a tooltip
  (K1, N1).
- Header pattern per §1.2.

### 2.5 Penny

- Header pattern per §1.2, with the Penny avatar and "Ask me anything about your money"
  as the subtitle, inside the 16 dp gutter.
- **Data-aware suggestion chips** (H4): up to 3, built in a UI-only provider from
  existing data, in priority order:
  1. an over-budget category → "Why is Dining Out over budget?"
  2. a savings gap → "Where should I cut to close my R 3 967 gap?"
  3. the largest category this week → "What did I spend on Groceries this week?"
  These fall back to today's generic chips when there's no data. They're never framed as
  alarms.
- While a reply loads, `mascot_thinking` replaces the typing dots (see §3.3).
- Copy fix: "analyze" → "analyse".

### 2.6 Settings (pushed from the avatar)

| Group | Rows |
|---|---|
| (card) | Profile: name + email (I1) |
| **Account** | Subscription (I4) · Security (I8, incl. Export data I8a, Delete account) · Privacy & consent (I3) |
| **Preferences** | Appearance (I7) · Notifications (I9) |
| **Data sources** | Bank notifications & email (I10, renamed from "Notification & email detection" so it no longer reads like the Notifications row; still contains "Review detected items") |
| | About (I11) |
| | **Log out** (I12), now behind a confirm dialog (N8) |

Savings plan (I5) is removed as a row; its home is Plan › Savings. Import history (I6)
moves to Transactions ⋮.

### 2.7 Onboarding (A7)

Same 6 pages and flow; the page copy and order follow the new tabs: Penny intro, Home,
Transactions, Plan, Invest + Penny, Security. Copy only.

---

## 3. Motion (expressive)

All motion uses the existing `AppMotion` tokens and is skipped (or swapped for an
instant change) when `context.reducedMotion` is true (J5). No sound, no confetti, no
looping animation on a resting screen.

### 3.1 Transitions

| Where | Motion | Token |
|---|---|---|
| Tab switch | **Fade-through** (out 90 ms, in 160 ms with a 0.92 → 1 scale), replacing today's 1 → 0 → 1 fade (B4) | `pageTransition` 250 ms |
| List row → detail (transaction, portfolio, account, goal) | **Container transform**: the row grows into the screen or sheet | `pageTransition`, `easeInOut` |
| Plan segments | **Shared axis X**: slides left/right in segment order | `pageTransition` |
| Settings from the avatar | **Shared axis Z** (comes forward), so it reads as "above" the tabs, not a sibling | `pageTransition` |
| Loading → content | Crossfade from skeleton | `stateChange` 200 ms |

The three Material patterns come from the first-party `animations` package. It's a
Flutter-team UI package, not a state or routing library, but it is a new dependency:
**approval item A1.** The alternative is to hand-roll them with `PageRouteBuilder`, at
about 1 extra day.

### 3.2 Feedback

| Where | Motion |
|---|---|
| Hero number changes | Counts up/down to the new value (`valueTransition` 400 ms), tabular figures so digits don't jitter |
| Progress bars (budgets, goals, savings) | Fill animates from the old value to the new one (400 ms) |
| Review swipe | The card follows the finger; past the threshold the background reveals ✓ Confirm (green) or Discard (neutral grey; red stays reserved); light haptic on commit |
| Save in any sheet | The sheet closes, then the new or changed row highlights briefly (fade from a tinted background, 600 ms) so you see where it went (N3, N7) |
| Press | 0.97 scale on cards and buttons (`feedback` 150 ms) |

### 3.3 Mascot moments

These are rewards for finishing something, never reminders of failing. Each plays once
per event, at most once a day per kind, and uses an existing asset clipped to a circle as
the app already does.

| Moment | Asset | Motion | Copy |
|---|---|---|---|
| Review queue cleared | `mascot_celebrating.jpg` | scale 0.8 → 1 + slight overshoot, 300 ms | "All caught up" (Y7: the peak-end for the daily loop, Q4) |
| A goal reaches 100 % | `mascot_celebrating.jpg` | same, on the goal card the first time it's seen complete | "{Goal} reached" |
| Savings gap closes for the month | `mascot_celebrating.jpg` | same, on the savings card | "Target met this month" |
| Penny is thinking | `mascot_thinking.jpg` | gentle 2 px bob while waiting, stops when the reply lands | — |
| Nothing spent today | `mascot_sleeping.jpg` | static | "Quiet day so far" under Spent today |
| Empty Transactions / Goals / Savings | `mascot_welcoming.jpg` | fade-in | existing empty-state copy |

**No sad or disappointed piggy**, ever: over budget, a missed target or a skipped day
gets plain numbers and no mascot (guardrails, H0). If you later want transparent PNG
poses or new poses, that's image generation, so it waits for your go-ahead.

---

## 4. The habit loop, checked against the Manipulation Matrix

| Stage | Design | Guardrail check |
|---|---|---|
| **External trigger** (H1) | Capture notifications (existing) and the review count. No new push notifications in this epic. | Badges count real pending items only |
| **Internal trigger** (H2) | "Can I afford this?" / "Am I OK this month?" are answered by the hero at 0 taps | — |
| **Action** (H3) | Open → glance (0 taps) → clear review (1 + 1 per item) → add cash spend (3 taps) | — |
| **Variable reward** (H4) | Left to spend moves daily; data-aware Penny chips; Needs attention changes with your data | Real data only; nothing invented to create curiosity |
| **Investment** (H5) | Confirming categories trains suggestions. The "All caught up" state adds one line when true: "Piggybank suggested the category for 9 of 10 this week." | Only shown when the number is real and positive |
| **Matrix (H0)** | It materially improves Tiaan's life, and Tiaan uses it himself → **Facilitator**. | No streaks, no guilt copy, no fake urgency, no "you haven't opened in N days" |

## 5. Destructive actions (Q7)

- **Undo instead of confirm** where the API call can be deferred: deleting a
  transaction, budget, goal, recurring cost, holding dividend or ledger contribution
  waits ~4 s behind an Undo snackbar before calling the API (the same pattern as review,
  J4). If the app is killed inside the window, nothing is deleted.
- **Confirm stays** where the stakes are high or the action isn't a single row: delete
  account, remove PIN, deactivate account, remove savings target, remove policy details,
  sell a holding, log out (new).

---

## 6. Core tasks after the rework

| Task | 1.0.8 | **After** | How |
|---|---|---|---|
| See today's spend | 0 | **0** | Hero sub-line |
| See what's left this month | 1+ and arithmetic | **0** | Hero |
| Review new transactions | 1 + 1/item (banner) · 3 without | **1 + 1/item · 2 without** | Home banner, or Transactions → Review |
| Add a manual transaction | 3 | **3** | Home FAB → chip → Save |
| Check a budget | 0–2 | **0–1** | Hero / Needs attention / Plan tab |
| Check the savings gap | 0 (detail 1) | **0 (detail 1)** | Savings card → Plan › Savings |
| Check goals | 2 | **1–2** | Plan → Goals (1 if Goals was the last segment) |
| Check investments | 1 | **1** | Invest tab |
| Ask Penny | 1 | **1**, and chips are about your data | Penny tab |
| Check a policy premium | 3* | **3** | Savings card → Policy check → Ask |
| Open Transactions | 1 (after a scroll) | **1** | Tab |
| Open Settings | 1 | **1** | Avatar |
| Accounts / Assets / Liabilities / Calculators | 1 | **2** | Net worth card → row. Accepted: weekly-or-rarer (Y15). |

\* 02-audit.md counted 4. The cost row already shows the Policy check button, so it's 3.

Every core task is ≤ 2 taps from a predictable place, the target set in 02.

---

## 7. Ten-question check

| # | Question | Answer |
|---|---|---|
| 1 | Purpose + one primary action obvious? | Every tab root names its question (§1.1) and has one FAB or one primary action. |
| 2 | Every core-loop tap unambiguous? | Review/Insights get labels or tooltips; the avatar does one thing; the bell is gone. |
| 3 | Home answers "OK today and this month?" without arithmetic? | Yes: the hero is the answer (Left to spend + Spent today). |
| 4 | Daily loop in a 30 s microbreak, ending in "all caught up"? | Glance → swipe the queue → "All caught up" moment. |
| 5 | Daily actions large, low, thumb zone? | Add FAB and review swipes are in the lower third; tabs at the bottom; ≥ 48 dp targets. |
| 6 | Feedback within 100–400 ms? | Press 150 ms, state 200 ms, transitions 250 ms, values 400 ms; skeletons instead of blank spinners. |
| 7 | Every destructive action undoable? | §5: undo where it can be deferred, confirm where it can't. |
| 8 | Frequent choices remembered/prefilled? | Last-used account, learned category chips, last Plan segment, current month. |
| 9 | Tabs earn their place; rare features not hidden? | §1.1. Rare screens sit 2 taps away behind visible cards or rows; nothing moves into a drawer. |
| 10 | Hooks pass the Matrix + guardrails? | §4. |

---

## 8. DESIGN.md changes this needs

These rewrite locked rules, so approving this spec approves them:

1. Navigation: 5 tabs become Home · Transactions · Plan · Invest · Penny. Settings is
   reached from the avatar.
2. Tab-root app bar: avatar (→ Settings) · title · ≤ 2 labelled actions. **The bell is
   removed** until a notification inbox exists.
3. Home: the hero is Left to spend; Net worth becomes a card; the new fixed order is §2.1.
   Still no customisation.
4. Motion: expressive, per §3, including mascot moments; still no confetti, streaks or
   badges (the review count isn't a badge in that sense: it counts real pending work).
5. New screens: Plan host, Net worth hub.

---

## 9. Old → new mapping (all 73 rows)

"Same" means the capability and its actions are unchanged; only the location column
matters.

| Row | New location | Depth before → after | Change |
|---|---|---|---|
| A1–A6 | Same routes | — | none |
| A7 | `/onboarding` | — | page copy follows the new tabs |
| A8 | `computeRedirect` | — | none; its tests must stay green |
| B1 | Shell: Home · Transactions · Plan · Invest · Penny | — | tab set changes; Settings to the avatar |
| B2, B3 | Shell | — | kept |
| B4 | Shell | — | fade → fade-through, still skipped on reduced motion |
| C1 | Home | — | kept |
| C2 | Home §1 | — | kept |
| C3 | Home §2, also on the Transactions tab | 1 → 1 | kept + second placement |
| C4 | Net worth card (Home §5) + Net worth screen | 0 → 0 | moved from hero to card |
| C5 | Hero sub-line (today) + hero (month) | 0 → 0 | restyled into the hero |
| C6 | Home §4 → Plan › Savings | 1 → 1 | target changes to the Plan segment |
| C7 | Home §6 Needs attention | 0 → 0 | skips completed goals; tappable |
| C8 | Transactions › Insights; Plan › Budgets "See trends" | 1 → 2 | card removed from Home |
| C9 | Net worth screen rows | 1 → 2 | quick links removed from Home |
| C10 | Home §7 → Transactions tab | 1 → 1 | "See all" switches tab |
| C11 | Home FAB | 1 → 1 | kept |
| C12 | — | — | **removed** (dead placeholder; DESIGN.md change 2) |
| D1, D2, D2a | Net worth → Accounts | 1 → 2 | Accounts' app-bar icon now switches to the Transactions tab |
| D3 | **Transactions tab** | 1 → 1 | becomes a tab root |
| D4 | Home FAB, Transactions FAB/row | 1 → 1 | unchanged sheet |
| D5 | Net worth → Assets | 1 → 2 | — |
| D6 | Net worth → Liabilities | 1 → 2 | — |
| D7 | Transactions ⋮ Expenses summary | 2 → 2 | app-bar icon → overflow |
| D8 | Transactions › Insights; Plan › Budgets link | 1 → 2 | — |
| D9 | Net worth → Loan calculators | 1 → 2 | — |
| D10 | Home banner; Transactions › Review; Settings › Data sources › Review | 1 or 3 → 1 or 2 | Review entry always visible on Transactions when pending > 0 |
| D11 | Transactions ⋮ Import | 2 → 2 | — |
| E1 | Plan segments (Budgets · Goals · Savings) | 1 → 1 | third segment added |
| E2 | Plan › Budgets | 1 → 1 | month switcher in the app bar; resets to the current month |
| E3 | Plan › Goals | 2 → 1–2 | in-progress first; Completed (n) group |
| F1 | Plan › Savings (Home card shortcut) | 1 → 1 | Settings row removed |
| F2, F3 | Plan › Savings | — | same; deletes get undo |
| F4 | Plan › Savings chip → Penny tab | — | same `go('/assistant')` |
| F5, F6 | Plan › Savings › cost › Policy check | 2 → 2 | — |
| G1–G6, G2a | Invest | — | skeleton + Retry; Compare labelled |
| H1 | Penny tab (`/assistant`) | 1 → 1 | data-aware chips; thinking mascot; "analyse" |
| I1 | Settings (avatar) › Profile | 2 → 2 | Settings is now a pushed route |
| I3 | Settings › Account › Privacy & consent | 2 → 2 | regrouped |
| I4 | Settings › Account › Subscription | 2 → 2 | regrouped |
| I5 | Plan › Savings | 2 → 1 | **row removed**; capability now in its home |
| I6 | Transactions ⋮ Import history | 2 → 2 | moved next to Import |
| I7 | Settings › Preferences › Appearance | 2 → 2 | regrouped |
| I8, I8a | Settings › Account › Security (+ `/settings/data-export`) | 2/3 → 2/3 | route kept |
| I9 | Settings › Preferences › Notifications | 2 → 2 | regrouped |
| I10 | Settings › Data sources › Bank notifications & email | 2 → 2 | renamed |
| I11 | Settings › About | 2 → 2 | — |
| I12 | Settings › Log out | 1 → 2 | now confirms (N8) |
| J1–J3, J6–J8 | Shared | — | kept |
| J4 | Undo snackbars | — | extended to deletes (§5) |
| J5 | `context.reducedMotion` | — | now gates every motion in §3 |

**Removed outright:** C12 (bell), a placeholder with no behaviour. **Entry points
removed:** I5 (Settings → Savings plan), replaced by the Plan tab. Every capability
survives.

---

## 10. Approval items

Reply with a yes/no or changes per item:

| # | Item | Recommendation |
|---|---|---|
| A1 | Add the `animations` package (first-party, UI only) for container transform, shared axis and fade-through | **Yes.** Already a dependency (`animations: ^3.0.0`, used by `app_theme.dart`), so no pubspec change. |
| A2 | Remove the bell (DESIGN.md change) | **Yes** |
| A3 | Proposals S, H, HP, G, ST (top of this doc) | **Yes** |
| A4 | Undo-instead-of-confirm for single-row deletes (§5) | **Yes** |
| A5 | Rename "Notification & email detection" → "Bank notifications & email" | **Yes** |
| A6 | The rework ships as one release at the end (so testers never see a half-moved app), with phases merged behind the existing tab structure until the final switch | **Yes**, or ship each phase if you'd rather see changes sooner |

## 11. Rough phasing (for the Session 3 blueprint)

1. **Shell and IA:** new tabs, Settings route from the avatar, Plan host with three
   segments (Savings embedded), Transactions as a tab, the header pattern, bell removal,
   the FAB padding rule. Inventory rows B, D3, E, F1, I re-ticked.
2. **Home:** hero states, Net worth card and Net worth screen, Needs attention, quick
   links and Trends card removed. Rows C, D1–D9 re-ticked.
3. **Screen fixes:** Transactions actions (Review, Insights, ⋮), Goals ordering, Invest
   skeleton/Retry/Compare label, Settings regroup and log-out confirm, Penny header and
   chips.
4. **Motion:** transitions, feedback, mascot moments, undo deletes; reduced-motion tests.
5. **Close-out:** onboarding copy, DESIGN.md update, a full on-device pass ticking all
   73 rows, and a fresh critique score (target ≥ 32/40).

Each phase is one PR with widget tests; `flutter analyze` and `flutter test` stay green.
