# Piggybank Visual UI/UX Audit (2026-09-11)

A visual design-quality pass using the `ui-ux-pro-max` skill's rule set (accessibility, touch/
interaction, style, layout, typography/color, forms/feedback, navigation, charts), run against 20
representative screens: Login, Dashboard, Accounts, Transactions, Budgets (empty state), Goals,
Invest, Loan Calculator/Accelerator, Notifications, Subscription, AI Assistant ("Penny"), Insights.

**Method note:** a live Android-emulator walkthrough was attempted first but the build was OOM-killed
twice on this machine (only ~3-4GB free of 16GB; `qemu-system-x86_64` alone was consuming several
GB). Rather than keep forcing a heavy rebuild, this audit reused the existing screenshots already
committed to `qa_screens/` from prior QA sessions (86 images, covering the full app) and verified
the more consequential visual claims against the actual Flutter source rather than guessing from
pixels alone (icon-tooltip coverage, dark-mode theme definition and contrast math, the Budgets
empty-state implementation). This is **not** a re-run of `QA_PRODUCTION_AUDIT_2026-09-11.md`'s
static+live scan (different skill, different rule set, no live device this time) — the two are
complementary, not overlapping.

---

## Top-line summary

**No Critical or High findings.** The app is visually clean and consistent — icon accessibility,
color contrast, brand consistency, and navigation are all in good shape, most of it attributable to
the production-audit fix-it work already completed and merged today (PRs #5, #6, #7). Two Medium/Low
items are worth doing something about; the rest is polish-tier.

| Severity | Count | Theme |
| --- | --- | --- |
| Critical | 0 | — |
| High | 0 | — |
| Medium | 1 | Budgets empty state gives no guidance |
| Low | 4 | Dead space on short-content screens, filled-vs-outline icon inconsistency, green's dual semantic duty, unverified dark-mode visual pass |

**Confirmed clean (verified against source, not just screenshots):**
- Every `IconButton` in the codebase has a `tooltip` (`grep -rln "IconButton(" lib/ | xargs grep -L "tooltip:"` → zero results) — the prior session's 12-file tooltip pass covered the whole app.
- Segmented controls (Budgets/Goals, Loan Calculator/Accelerator, transaction-type chips) pair color with a ✓ checkmark — color is never the only indicator.
- Bottom nav has 5 items (within the ≤5 guideline); every pushed screen has a consistent back arrow.
- Invest screen's donut chart has a proper legend (color dot + label + percentage text), not color-only.
- All icons are real vector/outline icons — no emoji, no raster icon blur.

---

## Medium

### M1. Budgets empty state gives no guidance
**File:** `lib/features/budgets/screens/budgets_screen.dart:66-68`
```dart
return ListView(
  padding: const EdgeInsets.all(16),
  children: const [Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('No budgets for this month.')))],
```
**Screen:** `qa_screens/budgets.png`
**Why it matters:** this is the one empty/zero state in the app that doesn't follow progressive-
disclosure guidance — it's a single, unstyled `Text` with no icon, no explanatory copy, and no
pointer to the "Add budget" FAB that's already floating in the corner. Every other zero-content
screen reviewed (Goals, Invest) either has real content or a clearer path forward.
**Suggested fix:** add an icon (e.g. a light pie-chart or wallet glyph matching the app's icon
family) plus a one-line sentence that references the Add Budget action, consistent with how other
screens narrate their primary action.

---

## Low

### L1. Dead space on short-content screens
**Screens:** `qa_screens/accounts.png`, `settings_screen.png` / `notifications.png`, `subscription.png`, `loancalc_filled.png`
**Why it matters:** Accounts, Notifications, Subscription, and the Calculators all leave roughly
50-70% of the viewport blank below their content on a tall phone (2400px emulator). Notifications
with just 2 toggle rows looks especially sparse. Not a defect, but a layout opportunity — e.g.
vertically centering short lists, or giving these screens a secondary module — rather than
top-anchoring content under a FAB pinned to the bottom corner.

**Step 4 re-verification (2026-09-13):** Notifications excluded from this pass — already
confirmed fixed and merged (`fix/notifications-dead-space`, commit `e9fa110`; see the blueprint's
Grounded section). Live-checked the remaining three screens on the `piggybank` Android emulator
(1080x2400, API 36) logged in as the demo account, in both Light and Dark appearance modes.
Screenshots committed under `qa_screens/l1_verify_*_{light,dark}_2026-09-13.png`.

- **Accounts — still open.** 3 account rows end around 45% down the viewport; the remaining
  ~50-55% is blank before the "Add account" FAB. Dark mode renders with correct contrast, no
  light-mode leftovers.
- **Subscription — still open, the worst of the three.** Plan card + "What Pro unlocks" list +
  "Cancel subscription" button end well under half the screen height; roughly 55-60% of the
  viewport is blank below. Same in both themes.
- **Loan Calculator — still open.** The three input fields + Calculate button end around
  35-40% down; the segmented Loan Calculator/Accelerator control at the top does not add enough
  content to offset it. Roughly 45-50% blank below the button in both themes.

Verdict: all three remain open exactly as originally described — no drift, no partial fixes.
Ready for Step 5's Stitch pass as scoped (Accounts, Subscription, Loan Calculator only).

### L2. Filled-vs-outline icon inconsistency
**Screens:** header avatar on `invest.png`, `budgets.png`, `insights.png`, `accounts.png`
**Why it matters:** the profile-avatar button is a solid filled green circle with a white
outline-person glyph, while every other icon in the app (back arrow, bell, filter, pie-chart,
upload, bottom-nav icons) is thin-stroke outline-only. Likely intentional (marks it as "the button
that opens your profile"), but it's the one filled/outline mix in an otherwise disciplined icon
system — worth a deliberate call rather than an incidental one.

**Decision (2026-09-11):** keep the filled avatar icon as-is. A visually distinct "profile entry
point" affordance is a common, intentional pattern — it distinguishes "opens your account" from
every other in-content icon, rather than reading as an inconsistency. No code change.

### L3. Green carries two semantic meanings at once
**File:** `lib/core/theme/app_theme.dart` (single accent color: `lightAccent`/`darkAccent`, doc
comment: *"Mostly white/black + one green accent"*)
**Why it matters:** the one brand accent is used for primary buttons, the active nav/tab state,
*and* "positive amount" (income, gains). On dense financial screens (Transactions, Invest) a green
number could momentarily read as "the tappable/brand thing" before "a positive value." It works
today because red is reserved exclusively for negative amounts, so the polarity signal survives —
this is a deliberate one-accent-color design trade-off per the theme file's own comment, not an
oversight, but worth knowing as a constraint if the palette ever expands.
**Related, not a UI defect:** on `invest.png`, the current demo data shows `-R 5 391 896,12
unrealized` against a `R 90 103,88` portfolio — a wildly out-of-scale negative figure that dominates
the screen's visual hierarchy. This is a seed-data quality issue (already tracked elsewhere in QA
history), not a UI bug, but it does visually distort this particular screen with today's demo data.

**Decision (2026-09-11):** closed, no action. This is already a deliberate one-accent-color
trade-off per `app_theme.dart`'s own comment, and red is reserved exclusively for negative
amounts so the polarity signal survives. No code change proposed.

### L4. Dark-mode visual pass unverified this session
**File:** `lib/core/theme/app_theme.dart:11,27` — code comment: *"Dark values are inferred (no dark
mockup was delivered)... unconfirmed."*
**Why it matters:** all `qa_screens/` captures are light-theme only, so this audit could not
visually confirm dark mode. Computed WCAG contrast ratios from the actual hex values are
reassuring — `darkTextMuted` #9AA69E on `darkBackground` #0F1412 ≈ 7.4:1, on `darkSurface` #181F1B
≈ 6.7:1; `darkDanger` #E8685F on `darkSurface` ≈ 5.3:1 — all clear the 4.5:1 floor with margin. But
"passes by calculation" isn't the same as "verified on a real dark-mode screen," which the code's
own comment says has never happened. A theme picker already exists at
`lib/features/settings/screens/appearance_screen.dart` (Light/Dark/System) — worth spending one
pass actually toggling it and screenshotting a few key screens.

**Decision (2026-09-11):** verified. Ran the app in release mode on the `piggybank` Android
emulator, switched Settings → Appearance → Dark, and screenshotted eight screens:
Appearance settings, Dashboard, Budgets (populated month and the M1 empty-state fix on a future
month), Notifications (confirms the L1 fix reads correctly in dark mode too), Transactions, the
biometric lock screen, and Login. All render with correct contrast, no unstyled/light-mode-leftover
surfaces, and ZAR comma-decimal formatting intact throughout. Screenshots committed under
`qa_screens/dark/`.

---

## Recommended next step

M1 is a cheap, contained fix (one screen, no cross-file impact). L4 is the one item worth a real
verification pass rather than a code change — toggle dark mode via Settings → Appearance and
screenshot Dashboard, Transactions, and Login to confirm the math holds up visually. L1-L3 are
polish-tier and can wait for a dedicated design pass.
