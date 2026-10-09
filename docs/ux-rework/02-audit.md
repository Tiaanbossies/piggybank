# UX rework 02: audit of the current app

Session 1 of the UX rework epic, written 2026-10-09. It measures where the app stands
before the spec (Session 2) changes anything. Principle IDs (K, N, Y, T, H, P) refer to
`01-principles.md`; capability IDs (A–J) refer to `03-capability-inventory.md`.

## How this was measured

| Source | What it covered | Limits |
|---|---|---|
| **Source read, `master` at 1.0.8+9** (`1d27263`) | Every tab, Savings plan, Policy, the add sheet, Settings, error states | The primary evidence. Where the source and a screenshot disagree, the source wins. |
| **Emulator, 1.0.7, signed-in session** (2026-10-08) | Home, Savings plan, Edit target sheet | Read-only: nothing saved, confirmed or swiped. 1.0.8 differs only in walkthrough polish and the consent-gate fix. |
| **Emulator, 1.0.3, demo account** (2026-10-09) | Tab headers, Budgets/Goals, Invest, Assistant, Settings | The emulator came back on an older image. The 1.0.8 release APK is signed differently, and reinstalling it would have wiped the sign-in. The backend was unreachable from it, so Invest showed its error state. Used only for things the source confirms are unchanged. |
| **Static scan** | `flutter analyze`: no issues. `flutter test`: 641 passing. | A clean baseline for the rework. Every phase PR must keep both green. |

## Score: 25/40 (was 21/40)

Nielsen's 10 heuristics, scored 0–4 like the 2026-10-06 baseline (which covered only the
daily flow). This pass covers all five tabs plus Savings and Policy.

| # | Heuristic | 10-06 | Now | Why it moved, or what still holds it back |
|---|---|---|---|---|
| 1 | Visibility of system status | 2 | **3** | "Spent today" and the review banner answer the daily questions on Home. Invest still shows a bare spinner while loading, and no screen says when data was last updated. |
| 2 | Match system / real world | 3 | 3 | Plain language. Exceptions: "Notification & email detection" is plumbing language, and Penny's empty state says "analyze" (US spelling). |
| 3 | User control and freedom | 3 | 3 | Undo on review and on recurring-cost suggestions. **Log out** fires immediately, with no confirmation. |
| 4 | Consistency and standards | 2 | 2 | Three different tab headers (below). The avatar and bell look tappable on three tabs and do nothing. FAB labels and placement vary per screen. |
| 5 | Error prevention | 2 | **3** | Learned categories, last-used account and an autofocused amount in the add sheet. |
| 6 | Recognition rather than recall | 2 | 2 | Transactions has no tab. Goals hides behind a segment. Review hides in Settings when the banner isn't showing. Policy sits 3 levels deep. |
| 7 | Flexibility and efficiency | 1 | **3** | One-tap and swipe review, the Home Add FAB with category chips, and a pre-filled "Where should I cut?" question for Penny. |
| 8 | Aesthetic and minimalist | 3 | **2** | Home grew to 11 sections plus a FAB, and the FAB now covers the fourth quick link. Net worth still takes the hero slot. |
| 9 | Error recovery | 1 | **2** | `InlineError` gained Retry, used on 8 screens. **Invest is still a dead end**: a centred line of text, no Retry (`invest_screen.dart:57`, `:132`). |
| 10 | Help and documentation | 2 | 2 | Good empty-state copy. Nothing contextual: "Fixed costs", "Everyday spending" and "Cut candidate" are never explained. |
| | **Total** | **21** | **25** | **Acceptable, trending up.** The gains came from the daily-flow PRs. What's left is structural (IA and consistency), which is this epic's job. |

## Cross-cutting findings

These are ordered by how much they cost a daily user.

1. **The IA has no home for the most-used list.** Transactions is reached by Home →
   scroll → "See all" (D3). Assistant takes a tab slot and is used far less. Violates
   Y15, T9 and K6 (trunk test: on Transactions the bottom bar highlights *Home*, so
   "where am I?" has a wrong answer).
2. **Settings is a junk drawer.** It holds account (Profile, Subscription, Security,
   Log out), preferences (Appearance, Notifications), data plumbing (Import history,
   Detection) and a **core feature**, Savings plan. Violates N5, Y4/Y12 and P2: a
   feature hidden in Settings is a hidden-nav problem.
3. **Two dead affordances in the app bar.** On Home, Invest and Budgets, the avatar
   (`CircleAvatar`, no `onTap`) and the bell (`Icon`, not a button) look tappable and
   do nothing. Violates N1 and K1. The bell is a locked DESIGN.md placeholder; the
   avatar isn't covered by any decision.
4. **Three tab-header styles.** Home, Invest and Budgets use avatar + title + bell.
   Assistant uses a custom Penny row with the icon flush to the screen edge (no 16 dp
   gutter). Settings uses a large in-body title and no app bar. Violates K4, Y1 and T6.
5. **Home is long and getting longer.** Its 11 sections (C2–C12) run about 2.5 screens
   tall on a 6.7" phone. The Add FAB sits over the Calculators quick link at rest
   (1.0.7 screenshot). Violates T13 (a dashboard shows *a few* indicators), Y2 and
   Y14. Fixed order is locked, so the spec has to cut or merge sections, not reorder
   them.
6. **The same task has two front doors that behave differently.** Savings plan has
   Home's card and Settings. Review has Home's banner (only when N > 0) and Settings →
   Detection → "Review detected items". Consent has a gate and Settings. Fine as
   shortcuts, but the Settings copies are where people go when the shortcut is absent
   (N9, T6).
7. **FABs collide with content.** On Home, the Add FAB covers a quick link. On Savings
   plan, "Add cost" covers the third cost's amount mid-scroll. The fix is bottom
   padding (≥ 88 dp), already a lesson from audit H2 (P3, P4).
8. **Loading and error states are uneven.** Invest shows a full-screen spinner and then
   a dead-end error. Other screens use `InlineError` with Retry. Violates Y5, P5 and N7.

## Screen by screen

The primary action is what the screen exists for. Violations are cited by principle ID.

| Screen | Purpose | Primary action | What works | Violations |
|---|---|---|---|---|
| **Home** (C1–C12) | "How am I doing today?" | Glance; Add; Review | Spent today is big and first after the hero. Review banner. Savings gap card with a clear next step ("Tap to find costs to cut"). | Net worth hero takes the prime slot for a number that barely moves day to day (Y10, T13, H4: no variability). 11 sections (Y2, Y14). FAB covers a quick link (P3). Quick links (Accounts, Assets, Liabilities, Calculators) are navigation dressed as content (N5). Dead avatar and bell (N1). |
| **Transactions** (D3–D4) | Find and fix a transaction | Search or filter, tap to edit | Filter chips, dated rows, shared sheet. | No tab: reached via Home → "See all" (T9, Y15). The bottom bar highlights Home while you're here (K6). |
| **Add sheet** (D4) | Log cash spend | Amount → chip → Save | Autofocus, decimal keypad, learned categories, last-used account. 3 taps. | None blocking. Account defaulting is invisible until you look (N7: show which account was assumed). |
| **Pending review** (D10) | Clear auto-captured items | Swipe or one tap per item | One tap, undo, failed commit restores the card. | When the banner is hidden, the only way in is Settings → Detection → Review (Y15, N9). |
| **Invest** (G1–G6) | "How are my investments?" | Glance; open a portfolio | Allocation donut, top holdings, Compare in the app bar. | Full-screen spinner, then a dead-end error with no Retry (Y5, N8). The Compare icon (`stacked_line_chart`) has no label: what it does isn't self-evident (K1, N1). |
| **Budgets / Goals** (E1–E3) | "Am I on budget?"; "How are my goals?" | Glance; edit a budget | Context-aware FAB; month chevrons. | Two features share one tab behind a segment, so Goals costs an extra tap and its state is easy to miss (N9, T6). Completed goals are listed first (Y8: put the goal you can still move first). |
| **Savings plan** (F1–F4) | "Will I hit my target?" | Read the gap; cut a cost | The gap headline is the right number. The breakdown (income − fixed − everyday = left over) is a clear conceptual model (N5). "Where should I cut? Ask Penny" is a well-placed internal-trigger hook (H2, H3). | Reached from Home's card or **Settings** (finding 2). "Add cost" FAB covers content (P3). Pushed inside whichever tab you came from, so the bottom bar's answer to "where am I?" depends on the route taken (K6). The Edit target sheet mixes floating labels with a placeholder-only "Monthly income" field (K4). |
| **Policy** (F5–F6) | "Am I overpaying for this cover?" | Fill the policy, ask Penny | Type-specific form; cited sources; honest "research paused" state. | Depth 3 (Home → Savings → cost → Policy check), and only for insurance rows, so it's undiscoverable (N9). A long form before any value is shown (T2, T4). |
| **Assistant** (H1) | Ask anything | Type or pick a chip | Suggested questions; Retry on a failed reply. | Generic chips that ignore the user's data (H4: no variable reward; K5). Header style differs from other tabs, with no gutter (K4, P3). "analyze" (SA English). Takes a tab slot for a low-frequency task (Y15). |
| **Settings** (I1–I12) | Account and preferences | Change a setting | Clear rows, grouped cards. | Holds Savings plan and data plumbing (finding 2). Log out has no confirmation (N8). Two "notification" rows (Notifications vs Notification & email detection) differ by a word but do unrelated things (Y12, K1). |

## Core tasks: tap counts

Counted from Home with the app open. Typing is not counted as a tap. "Before" is the
v1.0.4 table in `plans/ux-improvement-plan.md`; "Now" is 1.0.8, from the source.

| Task | v1.0.4 | **1.0.8 now** | Notes |
|---|---|---|---|
| See today's spend | Not possible | **0** | "Spent today" strip (C5). |
| Review new transactions | 3 to reach + ~4 per item | **1 + 1 per item** | Via the Home banner (C3). With no banner: **3** (Settings → Detection → Review). |
| Add a manual transaction | 8 + scroll + typing | **3 + typing** | FAB → category chip → Save; account defaulted. |
| Check a budget | 1–3 | **0–2** | 0 when Home's progress block shows the at-risk budget (C7). Otherwise 1 (Budgets tab), or 2 if the tab was left on Goals this session. |
| Check the savings plan / gap | n/a (new) | **0** to see the gap, **1** for detail | Home savings card (C6). From Settings it's 2. |
| Check goals | n/a | **2** | Budgets tab → Goals segment. 0 only if no budget is at risk and C7 falls through to a goal. |
| Check investments | n/a | **1** | Invest tab. |
| Ask Penny | n/a | **1 + typing** | Assistant tab. "Where should I cut?" is 2 (savings card → chip) and pre-fills the question. |
| Check a policy premium | n/a | **4** | Savings card → cost row → Policy check → Ask. |

**Reading the table.** The daily tasks are now cheap: 0–3 taps. The cost has moved to
*finding* things (Goals, Policy, Review without a banner, Transactions) and to the
weekly tasks that have no stable place. The spec should aim for **every core task in
≤ 2 taps from a predictable place** (K3, T6), not shave daily taps further.

## Habit loop check (H0–H5)

| Hook stage | Today | Gap |
|---|---|---|
| External trigger (H1) | The review banner, and capture notifications from the bank SMS. | No calm end-of-day trigger. The bell is a dead placeholder. |
| Internal trigger (H2) | "Did I overspend today?" is answered by Spent today. | Answered, but the answer isn't framed against anything ("R 0,00", versus what?). |
| Action (H3) | One-tap review; 3-tap add. | Good. |
| Variable reward (H4) | Weak. Net worth hero and Penny's chips barely change. | The spec needs one honest, changing number near the top, such as "left to spend this month" or the gap moving. |
| Investment (H5) | Confirming categories trains suggestions; cost decisions (Keep/Cut). | Not shown back to the user ("Piggybank now auto-categorises 82% of your spending"). |

Manipulation Matrix (H0): every hook above helps Tiaan (and testers) with something
they'd want and that Tiaan uses himself. That puts it in the "facilitator" quadrant, which is
acceptable. None of the current UI uses guilt, fake urgency or streaks; keep it that way.

## What the spec (Session 2) must decide

1. **D3, the tab set.** Promote Transactions and demote Assistant (Penny reached from
   Home and from contextual chips)? This is the biggest single IA fix (findings 1, 6).
2. **D1, the hero.** Does Net worth keep the top slot, or move behind a tap in favour
   of a daily, changing number?
3. **Where Savings plan lives.** Out of Settings, into Home, Budgets or its own tab,
   with Policy one level under it.
4. **What leaves Home.** Quick links and the Trends card are candidates to move into
   their natural parents (Accounts/Assets/Liabilities into a Net worth detail; Trends
   into Budgets/Transactions).
5. **One header pattern for all tabs.** Either make the avatar a real Profile/Settings
   entry or remove it, and settle on one title style.
6. **Goals.** Keep it as a segment or give it its own place, and list in-progress goals first.
7. **Settings scope.** Account + preferences only; detection and imports grouped as
   "Data sources".

Each answer has to keep every row in `03-capability-inventory.md` reachable.
