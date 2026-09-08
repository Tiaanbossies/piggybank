# Implementation Report: Replace Insights Tab with AI Assistant Tab

## Summary
Swapped the bottom nav's 4th tab from "Insights" (`InsightsScreen`, `/insights`) to "Assistant" (`ChatbotScreen`, `/assistant`). Per user decision, the Insights feature code and backend endpoints were left untouched — only the routing/nav wiring changed. The Settings-screen "AI Assistant" row (which used to push `ChatbotScreen`) was removed since the bottom-nav tab is now its sole entry point. Two stale doc comments and one design-doc line were corrected to match the new reality.

## Assessment vs Reality

| Metric | Predicted (Plan) | Actual |
|---|---|---|
| Complexity | Small | Small — confirmed |
| Confidence | 9/10 | Matched — zero deviations, zero surprises |
| Files Changed | 6 | 6 |

## Tasks Completed

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Swap the router branch | [done] Complete | Confirmed `chatbotControllerProvider` is `.autoDispose`, but `StatefulShellRoute.indexedStack` keeps each branch's widget subtree mounted across tab switches, so the screen's `ref.watch` keeps a live listener and conversation state persists as intended — no code change needed for this |
| 2 | Update the bottom nav destination | [done] Complete | |
| 3 | Remove the Settings entry point | [done] Complete | Removed both the `GroupRow` and its now-unused `ChatbotScreen` import |
| 4 | Fix the stale ChatbotScreen doc comment | [done] Complete | |
| 5 | Fix the stale InsightsScreen doc comment | [done] Complete | |
| 6 | Update DESIGN.md | [done] Complete | |

## Validation Results

| Level | Status | Notes |
|---|---|---|
| Static Analysis | [done] Pass | `flutter analyze`: 2 issues, both pre-existing/unrelated (`profile_api.dart` null-aware-marker infos) |
| Unit Tests | [done] Pass | Targeted run (router/chatbot/insights): 27/27. Full suite: 425/425. No new tests needed (see plan's Testing Strategy — pure UI wiring, no new logic) |
| Build | [done] Pass | `flutter build apk --debug` succeeded |
| Integration | N/A | No backend involved in this change |
| Edge Cases | N/A | Plan's checklist marked N/A — no new business logic/state introduced |

## Files Changed

| File | Action | Lines |
|---|---|---|
| `lib/core/router/app_router.dart` | UPDATED | +2 / -2 |
| `lib/core/router/app_shell.dart` | UPDATED | +1 / -1 |
| `lib/core/router/placeholder_screens.dart` | UPDATED | +0 / -8 |
| `lib/features/chatbot/screens/chatbot_screen.dart` | UPDATED | +7 / -5 |
| `lib/features/insights/screens/insights_screen.dart` | UPDATED | +6 / -1 |
| `DESIGN.md` | UPDATED | +1 / -1 |

## Deviations from Plan
None — implemented exactly as planned.

## Issues Encountered
None. The one thing flagged as a risk in the plan (Task 1's GOTCHA about `chatbotControllerProvider` being `.autoDispose`) was investigated and confirmed to be a non-issue: `StatefulShellRoute.indexedStack` keeps each tab's widget tree alive when switching tabs, so the provider's listener never drops and chat state persists correctly across tab switches.

## Tests Written
None — per the plan's Testing Strategy, this is a pure UI-wiring change with no new business logic, and the codebase has no existing precedent for a full-router/`AppShell` integration test (confirmed via search before planning). Existing tests for both `ChatbotScreen` and `InsightsScreen` (tested standalone, not through the router) continue to pass unmodified, confirming neither screen's own behavior was affected.

## Next Steps
- [ ] Code review via `/code-review`
- [ ] Manual on-device/emulator validation per the plan's Manual Validation checklist (nav labels, tab persistence, Settings row gone) — not done in this session, no running device/emulator available
- [ ] Create PR via `/prp-pr`
