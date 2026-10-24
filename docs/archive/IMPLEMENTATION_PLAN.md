# Piggybank Implementation Plan - Ready for Execution

**Status**: Planning complete. QA audit done. Ready to implement Tier 1 priority fixes.

---

## What's Complete (Background)

✓ **Phase 1-3 Core Features**: Auth, Accounts, Transactions, Budgets, Goals, Assets, Liabilities all have full CRUD  
✓ **Phase 4 Portfolios**: UI built (holdings, trades, dividends, TFSA/RA ledgers)  
✓ **Calculators**: 2 tools (loan calculator, loan accelerator)  
✓ **Dashboard**: Net worth, cashflow, progress, recent transactions  
✓ **Code Quality**: 9.5/10 (linter warnings fixed, analyzer tightened)  

---

## What Needs Work (Tier 1 - Critical)

### Tier 1: Critical User-Facing UX Gaps

**1. Transaction Filters** (Account/Date/Category)
- **Status**: Backend API supports filters; UI missing
- **Work**: Add filter entry point (icon in AppBar) → bottom sheet with dropdowns
- **Files**: `lib/features/transactions/screens/transactions_screen.dart`
- **Related**: `transactionFiltersProvider` (Riverpod state already exists)
- **Effort**: 1-2 hours

**2. Transaction Pagination**
- **Status**: Backend supports limit/offset; UI only loads first 50
- **Work**: Add "Load more" button at bottom of list OR implement infinite scroll
- **Files**: `lib/features/transactions/screens/transactions_screen.dart`
- **Effort**: 2-3 hours

**3. Account Edit Screen**
- **Status**: Deactivate mutation wired (Phase 2); no edit screen
- **Work**: Create new screen for edit (rename, institution, deactivate, restore); navigate from account list row tap
- **Files**: New file `lib/features/accounts/screens/account_detail_screen.dart`
- **Related**: `deactivateAccountProvider` already exists
- **Effort**: 3-4 hours

---

## What Would Be Nice (Tier 2/3 - Lower Priority)

**Tier 2** (Medium effort, high value):
- Liabilities payment history screen
- Expenses chart (month-by-month bar/line chart)
- Category picker for transactions
- Insights tab (net-worth trends, expense summary)

**Tier 3** (Lower value, polish):
- Settings completeness (biometric toggle, theme, notifications)
- Assets valuation date capture
- Deep-linking for push screens

---

## Next Steps

1. **Start with Tier 1.1 (Filters)** — highest ROI, moderate complexity
2. **Then Tier 1.2 (Pagination)** — straightforward, completes transaction UX
3. **Then Tier 1.3 (Account Edit)** — ties together deactivate feature + enables rename workflow

**Estimated timeline for Tier 1**: 6-9 hours of coding

Each item will include:
- Implementation (behavior-preserving)
- Unit tests for new providers/logic
- Manual testing against mock data
- Build verification

---

## Current Todo List

See **todo tool** output above for 12 executable items:
- **Tier 1 (3 items)**: Critical UX gaps
- **Tier 2 (4 items)**: Completeness enhancements
- **Tier 3 (1 item)**: Polish features
- **Testing (3 items)**: Integration tests for new features
- **Validation (1 item)**: Final build verification

Ready to start? Approve, and I'll begin with Tier 1.1 (Transaction Filters).

---

## Phase 8 Parity Sign-off (2026-08-23)

Formal close-out of Phase 8's "full pass against the Phase 0 feature-parity matrix," per Part 2 of `binary-popping-tower.md`. Route-completeness pass confirmed 9/9 old web routes have real Flutter coverage except `/insights` (documented deferred below). This section records that sign-off as a repo artifact rather than tribal knowledge in session files. No code changes accompany this entry.

| Item | Status | Disposition |
|---|---|---|
| Insights tab | Bare `PlaceholderScreen` | **Documented v1 exclusion** — PRO-gated/Ollama-dependent, per parity matrix's original deferred list. |
| Chatbot | No route at all | **Documented v1 exclusion** — same reasoning, matches deferred list. |
| RA/TFSA "estimated performance" backtest | Not built | **Documented v1 exclusion** — parity matrix already scoped this out explicitly (contribution CRUD itself is v1 and *is* built). |
| Dashboard widget customization | Not built | **Documented v1 exclusion** — parity matrix: "ship one well-designed default layout." |
| Admin | No route/screen anywhere | **Documented v1 exclusion** — internal-only per parity matrix; this pass adds the explicit sign-off line that was missing. |
| Instrument Comparison | Built **unconditionally** (always-visible toolbar icon in `InvestScreen`), not gated | **Confirmed intentional** — plan said "if kept in v1 per Phase 0 matrix review"; it was kept, and shipped as always-on rather than PRO-gated. Recorded here as the settled decision (no code change) unless PRO-gating is picked up as a separate small follow-up. |
| Settings sub-screens (Security, Notifications, Appearance, Subscription, Import history) | Not built, not routed | **Documented v1 exclusion**, already tracked as Tier 3 polish above. "Privacy & consent" is the one exception, now real per Part 1 of `binary-popping-tower.md`. |

