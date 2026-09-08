# Plan: Replace Insights Tab with AI Assistant Tab

## Summary
Swap the 4th bottom-navigation tab from the Insights Q&A screen to the existing AI Assistant (Chatbot) screen. This is a navigation/routing change only — per user decision, the Insights feature code and backend endpoints are **not** deleted, just unrouted. The Settings-screen entry point that currently pushes the Chatbot screen is removed, since the bottom-nav tab becomes its sole entry point.

## User Story
As a Piggybank user,
I want the AI Assistant (chat-style "Penny") front and center as a primary tab,
So that I can ask about my finances without digging through Settings, and I'm not shown two separate, overlapping AI-question surfaces (Insights' Q&A history list vs. the chat).

## Problem → Solution
**Current**: The bottom nav's 4th tab is "Insights" (`/insights` → `InsightsScreen`, a one-off question/answer list). The AI Assistant (`ChatbotScreen`, an ongoing chat thread, persona "Penny") is buried inside Settings, reached via `Navigator.push`.
**Desired**: The bottom nav's 4th tab is "Assistant" (`ChatbotScreen`, as a `StatefulShellBranch` so its conversation state persists across tab switches). Insights' code and backend stay in the repo, untouched, simply no longer linked from the router. The Settings row that used to push `ChatbotScreen` is removed (no more duplicate entry point).

## Metadata
- **Complexity**: Small
- **Source PRD**: N/A
- **PRD Phase**: N/A
- **Estimated Files**: 6 (2 code files with logic changes, 2 doc-comment-only code files, 1 design doc)

---

## UX Design

### Before
```
┌───────────────────────────────┐      ┌───────────────────────────────┐
│  Bottom nav (5 tabs):         │      │  Settings tab body            │
│  Home | Invest | Budgets |    │      │  ...                          │
│  [Insights] | Settings        │      │  ┌─────────────────────────┐ │
│                                │      │  │ 🤖 AI Assistant        →│ │  <- pushes ChatbotScreen
│  Insights tab body:            │      │  └─────────────────────────┘ │
│  [Ask a question box]          │      │  ...                          │
│  [Answer card]                 │      └───────────────────────────────┘
│  Past insights (history list)  │
└───────────────────────────────┘
```

### After
```
┌───────────────────────────────┐      ┌───────────────────────────────┐
│  Bottom nav (5 tabs):         │      │  Settings tab body            │
│  Home | Invest | Budgets |    │      │  ...                          │
│  [Assistant] | Settings       │      │  (AI Assistant row removed —  │
│                                │      │   Security/Notifications/     │
│  Assistant tab body:           │      │   Appearance/etc. unchanged)  │
│  "Hi, I'm Penny" chat thread   │      └───────────────────────────────┘
│  with suggested-question chips │
│  and a message composer        │
└───────────────────────────────┘
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Bottom nav, 4th slot | Icon `Icons.insights_outlined`/`Icons.insights`, label "Insights", route `/insights` → `InsightsScreen` | Icon `Icons.smart_toy_outlined`/`Icons.smart_toy`, label "Assistant", route `/assistant` → `ChatbotScreen` | `Icons.smart_toy_outlined` already used for the Settings row being removed — reuse it for visual continuity |
| Settings → "AI Assistant" row | `GroupRow` pushes `ChatbotScreen` via `MaterialPageRoute` | Row removed entirely | Avoids two navigation paths to the same screen |
| Chatbot conversation state | Reset every time the screen is pushed fresh from Settings | Persists across tab switches (StatefulShellBranch keeps each branch's own Navigator alive) | Behavior improvement, not a regression — confirm `chatbotControllerProvider` is a normal (non-autoDispose, or screen-scoped) provider so this doesn't break; see Task 1 GOTCHA |
| Insights screen | Reachable at `/insights` | Unreachable via UI navigation; code/tests/backend untouched (user's explicit "nav-only" choice) | `InsightsScreen`, its provider, API, model, and `backend/app/insights/*` are all left exactly as-is |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/core/router/app_router.dart` | 1-54 | Where the `/insights` branch is wired; must be edited |
| P0 | `lib/core/router/app_shell.dart` | 1-28 | Bottom nav destinations list; must be edited |
| P0 | `lib/core/router/placeholder_screens.dart` | 1-140 | Contains `SettingsScreen` with the "AI Assistant" `GroupRow` to remove |
| P1 | `lib/features/chatbot/screens/chatbot_screen.dart` | 1-30 | The screen being promoted to a tab; doc comment at top is now stale and must be updated |
| P1 | `lib/features/chatbot/providers/chatbot_provider.dart` | all | Confirm `chatbotControllerProvider`'s lifecycle before relying on cross-tab persistence |
| P2 | `lib/features/insights/screens/insights_screen.dart` | 14-29 | Doc comment references the `/insights` route directly by path; becomes inaccurate once the route is removed |
| P2 | `DESIGN.md` | 115-119 | Navigation section lists the 5 tabs by name; must be updated |
| P2 | `test/core/router/app_router_test.dart` | all | Confirms no test currently depends on the `/insights` path string (pure-function tests only) — read to confirm no update needed |
| P2 | `test/features/chatbot/screens/chatbot_screen_test.dart` | 1-50 | Confirms `ChatbotScreen` is tested standalone (via `ProviderScope` + `MaterialApp`), so promoting it to a tab requires no changes to this test |

## External Documentation
No external research needed — feature uses established internal patterns (go_router `StatefulShellRoute.indexedStack`, already used for all 5 existing tabs).

---

## Patterns to Mirror

### ROUTE_BRANCH_PATTERN
// SOURCE: lib/core/router/app_router.dart:42-51
```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const DashboardScreen())]),
    StatefulShellBranch(routes: [GoRoute(path: '/invest', builder: (context, state) => const InvestScreen())]),
    StatefulShellBranch(routes: [GoRoute(path: '/budgets', builder: (context, state) => const BudgetsHomeScreen())]),
    StatefulShellBranch(routes: [GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen())]),
    StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen())]),
  ],
),
```
Branch order must exactly match `AppShell`'s `destinations` order (index-parity, no explicit binding — this is how go_router's `StatefulShellRoute.indexedStack` works).

### NAV_DESTINATION_PATTERN
// SOURCE: lib/core/router/app_shell.dart:18-24
```dart
destinations: const [
  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
  NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: 'Invest'),
  NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Budgets'),
  NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Insights'),
  NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
],
```
Every destination uses an `_outlined` variant for unselected and the filled variant for selected — follow this exactly for the new entry.

### SETTINGS_GROUPROW_REMOVAL_PATTERN
// SOURCE: lib/core/router/placeholder_screens.dart:112-124
```dart
GroupRow(
  leadingIcon: Icons.smart_toy_outlined,
  title: 'AI Assistant',
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ChatbotScreen()),
  ),
),
```
This entire `GroupRow` block (inside the second `GroupCard` in `SettingsScreen.build`, alongside Import history/Appearance/Security/Notifications) is deleted. The surrounding `GroupCard`'s other rows are untouched.

### DOC_COMMENT_ACCURACY_PATTERN
// SOURCE: lib/features/chatbot/screens/chatbot_screen.dart:13-24
The class doc comment currently states the entry point is "pushed from Settings ... not from the Insights tab — Insights is still Step 7's bare 'coming soon' placeholder". Both clauses are now false (Insights is a real screen, just unrouted; Chatbot is now a tab, not pushed from Settings). This codebase's convention (seen throughout `insights_screen.dart`, `placeholder_screens.dart`) is doc comments that state *why*, kept accurate — stale comments are treated as defects here, not cosmetic debt.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/core/router/app_router.dart` | UPDATE | Replace the `/insights` branch with `/assistant` → `ChatbotScreen`; swap the `InsightsScreen` import for `ChatbotScreen` |
| `lib/core/router/app_shell.dart` | UPDATE | Replace the "Insights" `NavigationDestination` with an "Assistant" one |
| `lib/core/router/placeholder_screens.dart` | UPDATE | Remove the "AI Assistant" `GroupRow` from `SettingsScreen`; remove the now-unused `ChatbotScreen` import |
| `lib/features/chatbot/screens/chatbot_screen.dart` | UPDATE | Rewrite the stale entry-point doc comment (lines 13-24) to describe the new tab-based entry point |
| `lib/features/insights/screens/insights_screen.dart` | UPDATE | Rewrite the doc comment (lines 14-29) to note the screen is currently unrouted (kept for potential reuse), not "Replaces the `/insights` PlaceholderScreen" |
| `DESIGN.md` | UPDATE | Line 117: tab list `Home, Invest, Budgets, Insights, Settings` → `Home, Invest, Budgets, Assistant, Settings` |

## NOT Building
- Deleting `lib/features/insights/**` or its tests — explicitly out of scope per user decision (nav-only change).
- Deleting or modifying `backend/app/insights/*` (router, schemas) or any backend code — untouched.
- Any change to `ChatbotScreen`'s internal UI/logic, `chatbot_provider.dart`, or `chatbot_api.dart` — the screen is reused as-is.
- A route/path migration or redirect from old `/insights` URL to `/assistant` — there are no deep links or push-notification payloads referencing `/insights` in the app (confirmed via search), so no redirect shim is needed.
- New backend work of any kind.
- Renaming the `insights` feature folder, provider, or model files.

---

## Step-by-Step Tasks

### Task 1: Swap the router branch
- **ACTION**: In `lib/core/router/app_router.dart`, replace the `InsightsScreen` import and the 4th `StatefulShellBranch` entry.
- **IMPLEMENT**:
  - Remove: `import '../../features/insights/screens/insights_screen.dart';`
  - Add: `import '../../features/chatbot/screens/chatbot_screen.dart';`
  - Replace line 48:
    `StatefulShellBranch(routes: [GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen())]),`
    with:
    `StatefulShellBranch(routes: [GoRoute(path: '/assistant', builder: (context, state) => const ChatbotScreen())]),`
- **MIRROR**: `ROUTE_BRANCH_PATTERN` above — keep the branch in the same list position (4th), since `AppShell` binds destinations to branches purely by index.
- **IMPORTS**: `../../features/chatbot/screens/chatbot_screen.dart` (relative to `lib/core/router/`, same depth as the removed insights import).
- **GOTCHA**: `chatbotControllerProvider` (in `lib/features/chatbot/providers/chatbot_provider.dart`) was previously scoped to a screen that got popped and recreated on every Settings→push, so its lifecycle has never been exercised as a long-lived branch. Before finishing this task, read that provider file and confirm it is **not** `autoDispose` in a way that would wipe the conversation on tab switch (a plain `NotifierProvider`/`StateNotifierProvider` without `.autoDispose` persists correctly under `StatefulShellRoute.indexedStack`, since each branch keeps its own widget tree alive). If it *is* `autoDispose`, that's fine functionally (worst case: a fresh conversation each time the tab is revisited) but flag it as a UX note rather than a bug — do not add caching/persistence logic that wasn't asked for.
- **VALIDATE**: `flutter analyze` shows no unused-import or undefined-symbol errors in this file.

### Task 2: Update the bottom nav destination
- **ACTION**: In `lib/core/router/app_shell.dart`, replace the "Insights" destination.
- **IMPLEMENT**: Replace:
  `NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Insights'),`
  with:
  `NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'Assistant'),`
- **MIRROR**: `NAV_DESTINATION_PATTERN` above — same `_outlined`/filled icon-pair convention as every other destination.
- **IMPORTS**: None (Material icons already available via the existing `flutter/material.dart` import).
- **GOTCHA**: Keep this destination at index 3 (4th position) in the list — it must line up positionally with the branch reordered in Task 1. Do not reorder the other four.
- **VALIDATE**: `flutter analyze` clean; manual check (Task 6) that the label reads "Assistant" and the tab lands on the chat screen.

### Task 3: Remove the Settings entry point
- **ACTION**: In `lib/core/router/placeholder_screens.dart`, delete the "AI Assistant" `GroupRow` inside `SettingsScreen.build`, and drop the now-unused import.
- **IMPLEMENT**: Delete the `GroupRow` block matching `SETTINGS_GROUPROW_REMOVAL_PATTERN` above (the one with `leadingIcon: Icons.smart_toy_outlined, title: 'AI Assistant'`). Leave every other `GroupRow` in that `GroupCard` (Import history, Appearance, Security, Notifications) untouched, including their order and the `SizedBox`/`GroupCard` wrapper structure.
  Remove the import `import '../../features/chatbot/screens/chatbot_screen.dart';` from the top of this file — it becomes unused once the `GroupRow` is gone (this file has no other reference to `ChatbotScreen`).
- **MIRROR**: N/A — deletion task.
- **IMPORTS**: Remove only; nothing to add.
- **GOTCHA**: Don't remove a trailing/leading comma or `SizedBox` that would break the surrounding `GroupCard`'s children list — check the diff renders a valid `List<Widget>` (an odd one out here would be a compile error, not a silent bug, so `flutter analyze` will catch it).
- **VALIDATE**: `flutter analyze` shows no "unused_import" warning for this file and no syntax errors.

### Task 4: Fix the stale ChatbotScreen doc comment
- **ACTION**: Rewrite the class-level doc comment on `ChatbotScreen` (lines 13-24 of `lib/features/chatbot/screens/chatbot_screen.dart`).
- **IMPLEMENT**: Replace the "Entry point: pushed from Settings ... Revisit if/when Step 7 gives Insights its own real screen." paragraph (lines 20-24) with a short, accurate note, e.g.:
  ```
  /// Entry point: the bottom nav's "Assistant" tab (see `app_router.dart`'s
  /// `/assistant` branch and `app_shell.dart`'s destinations list). Previously
  /// reached only via a Settings row (`GroupRow`, `Navigator.push`); that row
  /// was removed once this became a primary tab, to avoid two navigation
  /// paths to the same screen. Formerly sat alongside Insights' one-off
  /// Q&A-history screen at the 4th tab slot; Insights' code is unrouted but
  /// still present under `lib/features/insights/` if ever revisited.
  ```
  Keep the first paragraph (lines 13-19, the bubble-layout vs. Insights'-Q&A-layout distinction) — it's still accurate and useful context, since `InsightsScreen`'s code and its distinct layout choice still exist in the repo.
- **MIRROR**: `DOC_COMMENT_ACCURACY_PATTERN` above.
- **IMPORTS**: None.
- **GOTCHA**: Don't delete the whole comment — the layout-comparison paragraph (bubbles vs. flat Q&A list) is genuinely useful design rationale that remains true.
- **VALIDATE**: Read-through only; no automated check for doc comments in this codebase (confirmed no doc-lint in `analysis_options.yaml`).

### Task 5: Fix the stale InsightsScreen doc comment
- **ACTION**: Update the class-level doc comment on `InsightsScreen` (lines 14-29 of `lib/features/insights/screens/insights_screen.dart`).
- **IMPLEMENT**: Change line 14 from:
  `/// Blueprint Step 7. Replaces the `/insights` `PlaceholderScreen`.`
  to something like:
  ```
  /// Blueprint Step 7. Originally replaced the `/insights` `PlaceholderScreen`
  /// and lived at the bottom nav's 4th tab slot. That slot now routes to
  /// `ChatbotScreen` (the AI Assistant) instead — this screen is currently
  /// unrouted (no `GoRoute` references it) but left in place, tests and all,
  /// in case the product decides to bring a distinct Q&A-history surface
  /// back later.
  ```
  Leave the rest of the comment (the `HeroMetricCard`/`ProgressCard` rationale, lines 16-29) as-is — it's still accurate design rationale for the screen's own layout, independent of whether it's currently routed.
- **MIRROR**: `DOC_COMMENT_ACCURACY_PATTERN` above.
- **IMPORTS**: None.
- **GOTCHA**: Do not touch anything below the doc comment — this is a comment-only edit; the class body, state, and `_AnswerCard` are untouched.
- **VALIDATE**: Read-through only.

### Task 6: Update DESIGN.md
- **ACTION**: Update the tab list in `DESIGN.md`'s Navigation section.
- **IMPLEMENT**: Change line 117 from:
  `Material 3 `NavigationBar` (bottom, 5 tabs: Home, Invest, Budgets, Insights, Settings),`
  to:
  `Material 3 `NavigationBar` (bottom, 5 tabs: Home, Invest, Budgets, Assistant, Settings),`
- **MIRROR**: N/A — doc edit.
- **IMPORTS**: None.
- **GOTCHA**: The following sentence ("unchanged — confirmed directly by every mockup...") technically stops being literally true for this one tab; leave it, since amending the mockup-provenance claim is out of scope for a nav-swap plan and would require re-deriving which mockups exist — flag this as a note for whoever next touches `DESIGN.md`'s Navigation section, not a blocker here.
- **VALIDATE**: Read-through only.

---

## Testing Strategy

### Unit Tests
No new unit tests are needed. Rationale, confirmed by reading the existing suite:
- `test/features/chatbot/**` tests `ChatbotScreen`/`ChatbotApi`/`chatbotControllerProvider` standalone (via `ProviderScope` + `MaterialApp(home: ChatbotScreen())`), never through the router — promoting the screen to a tab doesn't change any of its internal behavior, so these tests are unaffected and should still pass unmodified.
- `test/features/insights/**` tests `InsightsScreen` the same standalone way — unaffected by the route removal, still pass unmodified (per user's nav-only decision, this code isn't touched).
- `test/core/router/app_router_test.dart` only tests the pure `computeRedirect` function, which has no branch/path list logic in it (it doesn't reference `/insights` or `/assistant` at all) — unaffected.
- This codebase has **no existing test that pumps `AppShell` or the full `StatefulShellRoute` tree** (confirmed via search — no test file references `NavigationBar`, `NavigationDestination`, `bottomNavigationBar`, or `AppShell(`). Inventing a first-of-its-kind full-router integration test (mocking `authControllerProvider` into an authenticated+unlocked+consented state, pumping `MaterialApp.router`, tapping nav destinations) would be a new test pattern not established anywhere else in this suite — out of proportion for a nav-swap change. Verify this change manually instead (see Manual Validation below), matching this codebase's existing test-scope boundary.

### Edge Cases Checklist
- [ ] N/A — no new business logic, inputs, or state introduced by this change (pure UI wiring).

---

## Validation Commands

### Static Analysis
```bash
flutter analyze
```
EXPECT: Zero errors, zero warnings (specifically: no `unused_import` in `app_router.dart` or `placeholder_screens.dart`).

### Unit Tests
```bash
flutter test test/core/router/app_router_test.dart test/features/chatbot test/features/insights
```
EXPECT: All pass, unchanged pass count from before this change (confirms neither feature's own tests were affected).

### Full Test Suite
```bash
flutter test
```
EXPECT: No regressions anywhere else in the suite.

### Browser/Device Validation
```bash
flutter run
```
EXPECT: App launches, bottom nav shows "Assistant" (not "Insights") as the 4th tab.

### Manual Validation
- [ ] Log in, land on Home; bottom nav reads Home / Invest / Budgets / **Assistant** / Settings (no "Insights" anywhere in the nav bar).
- [ ] Tap "Assistant": lands on the "Hi, I'm Penny" chat screen (or the ongoing thread, if messages were sent earlier this session).
- [ ] Send a message on the Assistant tab, switch to Home, switch back to Assistant: the conversation is still there (confirms `StatefulShellBranch` state persistence — see Task 1's GOTCHA).
- [ ] Go to Settings: the "AI Assistant" row is gone; Profile, Privacy & consent, Subscription, Import history, Appearance, Security, Notifications, About, Log out rows are all still present and in the same order.
- [ ] Confirm no crash or blank screen when tapping the Assistant tab immediately after login (cold-start case).

---

## Acceptance Criteria
- [ ] All 6 tasks completed
- [ ] All validation commands pass
- [ ] `flutter analyze` clean
- [ ] No lint errors
- [ ] Bottom nav's 4th tab is "Assistant" → `ChatbotScreen`, at the same list position the "Insights" destination occupied
- [ ] Settings no longer has an "AI Assistant" row
- [ ] `lib/features/insights/**` and `backend/app/insights/**` are byte-for-byte untouched except the one doc-comment edit in Task 5

## Completion Checklist
- [ ] Code follows discovered patterns (`ROUTE_BRANCH_PATTERN`, `NAV_DESTINATION_PATTERN`)
- [ ] No dead imports left behind (`flutter analyze` confirms)
- [ ] Doc comments updated to match new reality (Tasks 4, 5)
- [ ] No unnecessary scope additions — Insights code/backend untouched, no new tests invented beyond the suite's existing scope boundary
- [ ] Self-contained — no questions needed during implementation

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `chatbotControllerProvider` is `autoDispose`-scoped and resets on every tab switch, undermining the "persists across tabs" UX win | Low | Low (functional regression is cosmetic — conversation just resets, same as today's Settings-push behavior) | Task 1's GOTCHA calls out reading the provider file first; if it is autoDispose, this is a note for the user, not a plan blocker — no unrequested caching logic should be added to fix it |
| A stakeholder screenshot/QA doc (`qa_screens/insights.png`, `docs/insights-design-note.md`) still gets referenced in a future QA pass and causes confusion about whether Insights is "live" | Low | Low | Task 5's doc-comment update on `InsightsScreen` itself is the durable signal; no changes to `qa_screens/` or `docs/insights-design-note.md` are needed since those are historical artifacts, not live-code claims |
| Someone later assumes the old `/insights` path still resolves (e.g. from muscle memory or an old bookmark/test) | Very Low | Low | Not a real risk for a mobile app (no URL bar); noted only for completeness |

## Notes
- The two "keep vs. delete" and "one vs. two entry points" scope questions were confirmed directly with the user before this plan was written: **keep Insights code/backend in place** (nav-only removal), **remove the duplicate Settings entry point** for AI Assistant.
- Chosen new route path is `/assistant` (not `/insights` repurposed) for clarity — it's a distinct feature, not a renamed one, and nothing in the app depends on the `/insights` path string surviving (confirmed via search).
- Chosen nav label is "Assistant" rather than "AI Assistant" to match the existing short, single-word convention of the other four tab labels (Home, Invest, Budgets, Settings) — the Settings row that specifically said "AI Assistant" is being removed anyway, so there's no strict-consistency requirement to reuse that exact string in the nav bar.
