# Tier 2 Feature Gaps - Completeness Phase

**Status**: Ready to start  
**Estimated Scope**: 8-12 hours across 4 features  
**Previous Session**: All Tier 1 critical features complete (32 tests, 0 issues)

---

## Overview

Tier 2 focuses on completing features that have full backend support but incomplete UI. These are "completeness" features — the app works fine without them, but they substantially improve user experience.

---

## Tier 2.1: Liabilities Payment History 📋

**Priority**: Medium  
**Complexity**: Low  
**Estimated Time**: 1-2 hours

### Current State
- ✅ Backend API supports payment history fetch
- ✅ Data model exists (`LiabilityPayment`)
- ✗ UI not built

### What to Build
- Add a "Payment History" card to the Liabilities screen
- Show recent 5-10 payments in a table/list
- Display: date, amount, balance-after
- Optional: "View all" link to full history screen

### Success Criteria
- Payment history renders correctly
- Dates formatted nicely (e.g., "Aug 21, 2024")
- Tests verify rendering with mock data
- Build succeeds with 0 new analyzer issues

### Related Files
```
lib/features/liabilities/screens/liabilities_screen.dart (main view)
lib/features/liabilities/data/liabilities_api.dart (API client)
lib/features/liabilities/models/liability.dart (data model)
```

---

## Tier 2.2: Expenses Chart 📊

**Priority**: High  
**Complexity**: Medium  
**Estimated Time**: 2-3 hours

### Current State
- ✅ Backend fetches expense breakdown by category
- ✅ `fl_chart` package imported but unused
- ✗ Chart not rendered

### What to Build
- Pie or bar chart showing expenses by category
- Display top 5-8 categories by amount
- Tap category to filter transactions to that category
- Optional: Show budget vs actual if budget data available

### Success Criteria
- Chart renders without crashing
- Categories labeled with amounts/percentages
- Color scheme matches app theme
- Tests verify chart data preparation
- Build succeeds

### Related Files
```
lib/features/dashboard/screens/dashboard_screen.dart
lib/features/expenses/screens/expenses_summary_screen.dart (uses fl_chart)
lib/features/transactions/providers/transactions_provider.dart
```

---

## Tier 2.3: Category Picker 🏷️

**Priority**: Low  
**Complexity**: Low  
**Estimated Time**: 1-1.5 hours

### Current State
- ✅ Free-text category input works
- ✗ No category suggestions/fixed list

### What to Build
- Replace free-text TextField with DropdownButtonFormField
- Source: Most recent categories from user's transaction history + defaults
- Allow custom entry fallback
- Autocomplete-style filtering (optional)

### Success Criteria
- Dropdown shows common categories
- Can still add custom categories
- Tests verify dropdown population
- No performance regression

### Related Files
```
lib/features/transactions/screens/transactions_screen.dart (_TransactionSheet)
```

---

## Tier 2.4: Insights Tab 🎯

**Priority**: Low  
**Complexity**: High  
**Estimated Time**: 4-6 hours

### Current State
- ✗ Stub only (shows empty screen)
- No data fetching or calculations

### What to Build (Option A: MVP)
- 3-4 simple insight cards:
  - **Savings Rate**: (Income - Expenses) / Income %
  - **Largest Expense Category**: Top category this month
  - **Monthly Trend**: Income/Expense sparkline
  - **Budget Health**: How many budgets are on track

### What to Build (Option B: Advanced)
- Time-series charts (6-month trends)
- Goal progress cards
- Forecast suggestions (e.g., "You'll reach Goal X in 3 months")

### Success Criteria
- At least 3 insights render correctly
- Data recalculates when transactions change
- No crashes or infinite loops
- Tests verify insight calculations

### Related Files
```
lib/features/insights/screens/insights_screen.dart (currently stub)
lib/features/insights/providers/ (need to create providers)
```

---

## Recommended Sequence

1. **Tier 2.2 (Expenses Chart)** — High impact, moderate effort, foundational for insights
2. **Tier 2.1 (Payment History)** — Quick win, straightforward card addition
3. **Tier 2.3 (Category Picker)** — Quality-of-life improvement, low risk
4. **Tier 2.4 (Insights)** — Optional polish if time permits

**Rationale**:
- Chart work unlocks insights work later
- Payment history is a fast confidence builder
- Category picker is a small UX win
- Insights can be deferred if needed

---

## Testing Strategy for Tier 2

For each feature:
1. **Unit tests**: Verify data transformations (e.g., category grouping for chart)
2. **Widget tests**: Verify UI renders with mock data
3. **Manual verification**: Build and tap through on emulator
4. **No integration tests**: (Backend mocked in dev)

**Target**: 20-30 new tests across all Tier 2 features.

---

## Technical Notes

### fl_chart Integration
- Already in `pubspec.yaml`
- Uses Riverpod for data access
- Example in `expenses_summary_screen.dart` (partially written)

### Backend Assumptions
All endpoints assumed to exist:
- ✅ GET `/liabilities/{id}/payments` — Fetch payment history
- ✅ GET `/transactions/?category=...` — Filter by category (for chart interactivity)
- ✅ All existing budget/goal/transaction endpoints

### Riverpod Patterns to Use
- `FutureProvider` for data fetching
- `StateNotifier` for local UI state (e.g., selected chart category)
- `.select()` for derived data (e.g., "top 5 categories")

---

## Definition of Done (Per Tier 2 Feature)

- [ ] Feature complete and tested
- [ ] `flutter analyze` shows 0 new issues
- [ ] `flutter build apk --debug` succeeds
- [ ] Unit/widget tests included
- [ ] No changes to existing Tier 1 features
- [ ] Git commit(s) with clear messages

---

## Out of Scope (Tier 3+)

- Settings screen
- Profile/account management
- Push notifications
- Export/reports
- Dark mode
- Internationalization (i18n)

---

## Success Criteria for Session

✅ At least Tier 2.2 (Expenses Chart) complete  
✅ All existing tests still passing  
✅ 0 new analyzer issues  
✅ 20+ new unit/widget tests  
✅ Clean build  

Optional stretch goals:
- Tier 2.1 + 2.2 complete
- Tier 2.3 started

---

## Resources

- Main app: `/lib`
- Tests: `/test`
- QA findings: `QA_FINDINGS.md`
- Implementation plan: `IMPLEMENTATION_PLAN.md`
- Previous session report: `SESSION_TIER1_COMPLETE.md`

---

## Quick Start

```bash
# Pull latest
git pull

# Verify Tier 1 still works
flutter test
flutter analyze
flutter build apk --debug

# Create feature branch (optional)
git checkout -b tier2/expenses-chart

# Start coding!
```

**Ready to go!** 🚀
