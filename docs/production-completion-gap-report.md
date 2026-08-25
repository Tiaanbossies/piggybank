# Piggybank: Production-Completion Gap Report

**Status:** Audit only — no code changed. Produced by 3 parallel read-only Explore
agents against the current repo state (post Phase 8: `Piggybank` @ `70d180b`,
`finance-app.v3-main` @ `2e4d959`).

**Scope of this pass:** reverses the Phase 8 v1-exclusion sign-off in
`IMPLEMENTATION_PLAN.md` — the 7 items marked "documented v1 exclusion" there are now
in scope to build, alongside Google Play distribution readiness (previously
sideload-only).

---

## 1. Core domains — already complete, no action needed

Confirmed full Flutter coverage against a real backend for: auth, consents, accounts,
transactions, assets, liabilities, budgets, imports, portfolios (incl. holdings,
dividends, trades, TFSA/RA ledgers), expenses, summaries, goals. **One small,
previously-unflagged gap**: Instrument Comparison's benchmark overlay (CPI/STeFI),
CSV export, and shareable URL state are not ported from the web app — matches the web
app's own "coming soon" status, low priority, optional pickup.

## 2. The 6 reversed exclusions — scoped and ordered by dependency

| Item | Existing spec | Backend readiness | Size | Order |
|---|---|---|---|---|
| **RA/TFSA "backtest"** | Web precedent is a trivial client-side compounding calculator with a disclaimer, not a real backtest | No backend needed — pure client math | Small | **1st** — cheapest, zero dependencies |
| **Settings: Subscription** | `stitch-design-brief.md` §8 | Ready — `GET /`, `POST /upgrade`/`/cancel` | Small | 2nd |
| **Settings: Import history** | `stitch-design-brief.md` §8 | Ready — `GET` list-imports w/ status | Small | 2nd |
| **Settings: Appearance** | `stitch-design-brief.md` §8 | Client-only (theme preference) | Small | 3rd |
| **Settings: Security** | `stitch-design-brief.md` §8 | **Needs backend work** — no PIN field on `User` model | Medium | 4th |
| **Settings: Notifications** | `stitch-design-brief.md` §8 | **Needs backend work** — no notification-preferences module exists | Medium | 4th |
| **Insights tab** | Extensive — `stitch-design-brief.md` §8, legacy `InsightsPage.tsx` | Backend fully built (Q&A, rate-limited, persisted), **conditionally mounted only when `AI_FEATURES_ENABLED=true`** — currently `false`, Ollama not running | Medium | 5th — build UI now, but real answers blocked on ops turning AI on |
| **Chatbot** | None — explicitly "mention only" in design docs; legacy `ChatPage.tsx` as reference | Same as Insights — fully built, same AI-gate dependency | Medium-large | 6th — after Insights proves the pattern; more IA design risk since no mockup exists |
| **Admin** | **Zero product definition anywhere** — no mockup, no doc mention | Backend is one endpoint: `POST /admin/refresh-prices` (background job trigger). No user mgmt, no analytics, nothing else | Large *if* scoped as a real panel, small if scoped to the one endpoint | **Needs a scoping decision before any build** — see Open Questions |
| **Dashboard customization** | **Contradicts existing signed-off decision** ("fixed order, not customizable") — no prior design work at all | No backend storage for layout preferences exists | Large — new backend field/table, picker UI, reorder interaction | **Last** — biggest scope, lowest confidence this is actually wanted (see Open Questions) |

## 3. Test coverage

Thin everywhere. Every covered domain has model-level tests at best; almost none have
widget/screen tests; **no domain has full-stack (data+model+provider+screen) coverage**.
Zero test files exist for: `assets`, `auth`, `budgets`, `calculators`, `dashboard`,
`goals`, `summaries`. `core/consents` and `core/theme` also have zero tests.

## 4. Google Play readiness gaps

| Item | Status |
|---|---|
| Signing | Still debug-signed (`android/app/build.gradle.kts` has a `// TODO` for release signing). No keystore file exists. **No `.gitignore` entry protects a future keystore from being committed.** |
| App identity | `za.co.fynboscreative.piggybank` — confirmed, permanent-once-published |
| Version | `pubspec.yaml: 1.0.0+1` — fine as a starting point |
| min/target/compile SDK | Defaulted to Flutter's own Gradle plugin values, not hardcoded — needs external verification against current Play Store policy |
| **Privacy policy URL** | **None exists.** The only privacy-policy content (`PrivacyPolicyPage.tsx`) now lives in `finance-app.v3-main/legacy/react-web/`, explicitly "not built, run, or deployed." Caddy serves only the API, nothing static. This is a hard Play Store listing requirement. |
| Launcher icons | Likely still Flutter's default template icon — no `flutter_launcher_icons` config, no custom icon source asset anywhere in the repo, no 512×512 store-listing icon |
| Store listing assets | None — `assets/` holds only the 9 original design-reference mockup JPEGs, no store screenshots, no feature graphic, no description copy |
| Content rating / Data safety | Play Console questionnaire items, not a code task |

---

## Open Questions (need your call before Step 2's plan can be finalized)

1. **Admin** — genuinely nothing exists to build against. Do you want (a) a minimal client feature exposing just the one real endpoint (a "Refresh prices" button somewhere in Settings/Admin), (b) a real admin panel scoped from scratch (needs a separate product-definition conversation — what should an admin actually see/do?), or (c) drop this from the reversal and leave it excluded?
2. **Dashboard customization** — this is the one item that actively reverses a considered decision ("ship one well-designed fixed layout"), not just fills a gap. Do you actually want widget reordering/picking, or would re-confirming the fixed layout (and treating "customization" as no longer wanted) be the more honest call now that it's been scoped?
3. **AI enablement (Insights + Chatbot)** — building the Flutter UI can start now, but real answers need Ollama running on the deployed server (`100.121.165.7`) and `AI_FEATURES_ENABLED=true`. Do you want that ops work sequenced as its own phase (stand up Ollama, verify GPU/CPU capacity on the home box) before or in parallel with the Flutter UI work?
