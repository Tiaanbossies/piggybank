# Stitch vs. Live Emulator — Screen-by-Screen Verification

Working checklist for comparing every Stitch design mock (project `4011413732038259168`)
against how it actually renders in the Piggybank Flutter app on a live Android emulator.
Started 2026-09-01, per `/ecc:prompt-optimizer`'s optimized prompt (user: "I still don't see
some of the screens the way it is rendered in Stitch, lets go and review each Stitch screen
against the live emulator to verify they are correct, 1 by 1").

Verdicts: **MATCH** / **MISMATCH** (structure or token issue, described) / **NO FLUTTER**
(Stitch mock exists, no corresponding built screen — not a bug, just unbuilt scope) / **NO
STITCH** (Flutter screen exists, no design mock — reverse gap, noted for awareness only).

Full pass first — do not fix anything until every row below has a recorded verdict.

## IMPORTANT — scope pivot discovered mid-sweep (2026-09-01)

The current Stitch project (`4011413732038259168`, brief: `docs/stitch-design-brief.md`,
Aug 23) is **explicitly documented as "exploratory, not canonical" — "a full-app redesign
exploration rather than a locked-identity refresh."** It is not a spec the app already failed
to match. The app was actually built against an *earlier* brief (`docs/ui-ux-mockup-brief.md`,
Aug 17), whose resulting mockups are saved locally as `assets/login.jpeg`, `dashboard.jpeg`,
`accounts.jpeg`, `budgets.jpeg`, `goals.jpeg`, `investments.jpeg`, `register.jpeg`,
`settings.jpeg`, `transactions.jpeg` — confirmed by comparing `assets/login.jpeg` against the
live Login screen: tagline, "Forgot password?" placement, and footer copy all match the local
reference, NOT the current Stitch project's Login mock (different tagline, different mascot
render, "Forgot?" placed differently).

Discovered on Login while starting the sweep: the real Piggybank mascot/logo images already
exist in `assets/` (`Piggybank mascot.jpeg`, `Piggybank app logo.jpeg`) but `pubspec.yaml`'s
`assets:` section was entirely commented out, so three screens — Login, Lock Screen, Register —
fell back to a generic `Icons.savings` placeholder, each with an explicit code comment saying
so ("Placeholder for the mockups' 3D piggy-bank mascot illustration — no real asset exists
yet"). This is a real, concrete gap independent of which design brief is authoritative.

**User decision, asked mid-sweep:** rather than (a) a full redesign-adoption sweep against the
exploratory Stitch project, or (b) re-scoping the whole comparison to the older local mockups,
fix the concrete mascot/asset-wiring gap only. **Status: DONE** — see Step 2 below. The broader
39-screen full sweep was paused here rather than continued against a redesign that isn't meant
to be a fix target yet; resume it (with an explicit choice of baseline) if/when wanted.

## Step 1 — Stitch-side status (resolved)

- Imports Wizard — confirmed generated (2 copies exist — duplicate, not a blocker).
- Financial Assistant: Welcome / Chat Thread (Chatbot/Penny) — confirmed generated.
- Admin Dashboard — confirmed generated. **NO FLUTTER** — Admin has no client UI per the
  fix-it blueprint's L6 decision ("leave both as-is"). Not a mismatch to fix.
- User Management — confirmed generated. **NO FLUTTER** — same as above, presumed to be the
  admin user list/detail mock; not comparable against a build that doesn't exist.
- Loan Calculator — 2 exact-title duplicates in Stitch (harmless, noted for Stitch-side
  cleanup only, not an app-code issue).

## Step 2 — Screen checklist

| Stitch title | Flutter screen (best-guess mapping) | Verdict | Notes |
|---|---|---|---|
| Login | `auth/screens/login_screen.dart` | **FIXED** | Mascot was `Icons.savings` placeholder — now real `assets/mascot.jpg`, confirmed live (rebuilt debug APK, screenshot). Other Stitch-vs-live differences (tagline, button style, "Forgot?" placement) are the exploratory-redesign gap noted above, not touched. |
| Forgot password | `auth/screens/forgot_password_screen.dart` | TBD | |
| Reset Password | `auth/screens/reset_password_screen.dart` | TBD | |
| Lock Screen: PIN Entry | `auth/screens/lock_screen.dart` | **FIXED** | Same mascot placeholder fix. Verified via `flutter analyze` (clean) + `lock_screen_test.dart` (5/5 passing) — live screenshot not captured (emulator IME made demo login unreliable this session), but the code change is byte-identical in pattern to Login/Register, both live-confirmed, and the Column here has no `stretch` cross-axis issue (default `center`, unlike Register's bug — see below). |
| Lock Screen: PIN Entry (Error State) | `auth/screens/lock_screen.dart` (error state) | **FIXED** | Same fix, same widget. |
| Lock Screen: Biometric | `auth/screens/lock_screen.dart` (biometric variant) | **FIXED** | Same fix, same widget. |
| Privacy & Consent: First-run Gate | `consent/screens/consent_screen.dart` | TBD | |
| Privacy & Consent: Review (Settings) | `consent/screens/consent_screen.dart` (settings entry) | TBD | |
| Dashboard | `dashboard/screens/dashboard_screen.dart` | TBD | |
| Accounts | `accounts/screens/accounts_screen.dart` | TBD | |
| Add account | `accounts/screens/account_edit_screen.dart` (create mode) | TBD | |
| — (register, no separate Stitch title but same brief covers it) | `auth/screens/register_screen.dart` | **FIXED** | Same mascot placeholder fix as Login/Lock — found the same "Placeholder for the mockups' 3D piggy-bank mascot illustration" comment. Fixing this one surfaced a second bug: the parent `Column` uses `CrossAxisAlignment.stretch`, which stretched the fixed-size mascot image to full width until wrapped in `Center` (matching Login's pattern). Confirmed live both before (stretched, wrong) and after (correct) via rebuilt debug APK screenshots. |
| — (no Stitch mock) | `accounts/screens/account_detail_screen.dart` | **NO STITCH** | Built in the fix-it blueprint (L4), after this Stitch project's most recent screens — never mocked. Reverse gap, not this pass's focus, but flagging. |
| Transactions | `transactions/screens/transactions_screen.dart` | TBD | |
| Add transaction | transactions add flow (sheet/dialog — confirm exact widget) | TBD | |
| Budgets | `budgets/screens/budgets_screen.dart` / `budgets_home_screen.dart` | TBD | Two budget screen files — confirm which the Stitch mock maps to. |
| Goals | `goals/screens/goals_screen.dart` | TBD | |
| Assets | `assets/screens/assets_screen.dart` | TBD | |
| Liabilities | `liabilities/screens/liabilities_screen.dart` | TBD | |
| — (no Stitch mock) | `liabilities/screens/liability_detail_screen.dart` | **NO STITCH** | |
| Invest | `portfolios/screens/invest_screen.dart` | TBD | |
| Portfolio Detail | `portfolios/screens/portfolio_detail_screen.dart` | TBD | |
| Holding Detail Sheet | `portfolios/screens/holding_detail_sheet.dart` | TBD | |
| Compare: Correlation Heatmap | `portfolios/screens/instrument_comparison_screen.dart` (tab) | TBD | |
| Compare: Factsheets | `portfolios/screens/instrument_comparison_screen.dart` (tab) | TBD | |
| Compare: Risk Metrics (Data Scannability) | `portfolios/screens/instrument_comparison_screen.dart` (tab) | TBD | |
| Expenses Summary | `expenses/screens/expenses_summary_screen.dart` | TBD | |
| Insights | `insights/screens/insights_screen.dart` | TBD | |
| Loan Calculator | `calculators/screens/calculators_screen.dart` | TBD | |
| Loan Accelerator | `calculators/screens/calculators_screen.dart` (accelerator mode/tab) | TBD | |
| Import history | `settings/screens/import_history_screen.dart` | TBD | |
| Settings | `core/router/placeholder_screens.dart`'s `SettingsScreen` | TBD | Real implementation despite the filename — uses plain Material icons/ListView per its own code comment; worth checking against Stitch's card language explicitly. |
| Appearance Settings | `settings/screens/appearance_screen.dart` | TBD | |
| Security Settings | `settings/screens/security_screen.dart` | TBD | |
| Notifications Settings | `settings/screens/notifications_screen.dart` | TBD | |
| Subscription Settings | `settings/screens/subscription_screen.dart` | TBD | |
| Financial Assistant: Welcome | `chatbot/screens/chatbot_screen.dart` (empty state) | TBD | |
| Financial Assistant: Chat Thread | `chatbot/screens/chatbot_screen.dart` (with messages) | TBD | |
| Imports Wizard | `imports/screens/imports_screen.dart` | TBD | |
| Admin Dashboard | — | **NO FLUTTER** | See Step 1. |
| User Management | — | **NO FLUTTER** | See Step 1. |

**Flutter screens with no Stitch mock found at all** (register, TFSA/RA ledgers, data export,
portfolio/holding edit sheets) — not this pass's focus (comparing Stitch → live), but noted:
`auth/screens/register_screen.dart`, `tfsa/screens/tfsa_ledger_screen.dart`,
`ra/screens/ra_ledger_screen.dart`, `settings/screens/data_export_screen.dart`,
`portfolios/screens/add_edit_holding_sheet.dart`, `portfolios/screens/portfolio_sheet.dart`,
`portfolios/screens/sell_holding_sheet.dart`, `portfolios/screens/all_holdings_screen.dart`.

## Step 3 — Live comparison log

Sweep paused after the mascot fix (2026-09-01) — see the scope-pivot note at the top. Remaining
rows in Step 2's table are still `TBD`. Resume by picking an explicit baseline first (current
exploratory Stitch project as a redesign target, vs. the older `docs/ui-ux-mockup-brief.md`
mockups the app already targets) rather than assuming the current Stitch project is "correct."

**Verification for this pass's fix:**
- `flutter analyze` — No issues found.
- `flutter test` — 425/425 passing (full suite, includes `lock_screen_test.dart` 5/5).
- Live: Login and Register screenshotted on a fresh debug-APK install/reinstall against a
  clean emulator (`pm clear`, fresh launch) — mascot renders correctly, properly sized and
  centered on both. Lock Screen not live-screenshotted this session (see table note above).
