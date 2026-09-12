# Blueprint: Penny's first-run onboarding tour

**Objective:** When a user creates a Piggybank account for the first time, show a short,
professional, animated tour led by the Penny mascot (the piggy-bank illustration already used on
Login/Register/Lock — `assets/mascot.jpg`) that introduces the app's five main areas (Home,
Invest, Budgets, Assistant, Settings) before they land on the dashboard. Returning users who log
in or have their session restored never see it. **Phase 1 only** — a standalone tour screen, not a
live coach-mark overlay on the real app (see "Explicitly out of scope").

**User's own framing (verbatim intent):** "if a user creates a account for the first time, Penny
takes them through the app, and shows them all the functionality and capabilities. It needs to
look professional, informative and clean." Confirmed via clarifying question: build the standalone
tour now; live spotlight coach-marks on real screens are an explicit later phase, not part of this
plan.

**Mode:** Git branches + manual PR (no `gh` CLI on this machine — confirmed `gh: command not
found`). `Piggybank` has a real `origin` remote
(`https://github.com/Tiaanbossies/piggybank.git`, default branch `master`) — push each branch and
open the PR manually via the browser link Git prints after `git push`, matching how prior sessions'
PRs were created. `git status --short --branch` currently shows `master` 16 commits ahead of
`origin/master` with a clean working tree — no pre-flight commit needed before Step 1's branch.

**Grounded against the live files before drafting (2026-09-12):**
- `lib/core/auth/auth_state.dart` — `AuthState` currently has `status`, `accessToken`, `user`,
  `locked`, `consentsRequired`. No onboarding-related field exists yet.
- `lib/core/auth/auth_controller.dart` — `register()`, `login()`, and `restoreSession()` are three
  distinct code paths; only `register()` ever *sets* the pending flag, but all three must *derive*
  `onboardingRequired` from it (see Step 1's revised design — an earlier draft of this plan made the
  flag write-only, which silently lost the tour forever if the app was force-quit mid-tour; caught
  in adversarial review). `_checkConsentsRequired` is the precedent pattern for a state-derived
  gate; `authControllerProvider`'s construction (`authApi`, `secureStorage`, `localAuth`) is at the
  bottom of the file (~line 194) and needs a fourth dependency wired in. **`AuthController` is also
  constructed directly at `test/core/auth/auth_controller_test.dart:76-80, 186-190, 202-206`** — all
  three call sites need the new constructor param added or the test file won't compile.
- `lib/core/router/app_router.dart` — `computeRedirect(AuthState, String)` is a pure, unit-tested
  function with explicit precedence: `locked` wins over `consentsRequired`. The new gate slots in
  right after `consentsRequired`, before the shell fallback. Route list needs one new
  `GoRoute(path: '/onboarding', ...)`.
- `lib/core/auth/biometric_preference.dart` — the exact pattern to mirror for a
  `SharedPreferences`-backed local flag (`sharedPreferencesProvider` override in `main()`,
  `_prefs.getBool(key) ?? default`). This plan's `OnboardingStore` is plain (not a
  `StateNotifier`) because `AuthController` needs to read/write it directly, not watch it.
- `lib/core/theme/app_motion.dart` — the shared motion vocabulary (`AppMotion.easeOut`,
  `AppMotion.easeInOut`, durations, `context.reducedMotion`) that every animation in this app is
  expected to route through, per the 2026-09 animation audit. The tour's Penny idle-bob and
  slide-in animations must use these tokens, not hand-typed curves/durations.
- `lib/features/auth/screens/login_screen.dart:78-81` — the exact mascot presentation pattern to
  reuse: `ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/mascot.jpg',
  width: 120, height: 120, fit: BoxFit.cover))`. No new image asset is needed.
- `lib/core/router/app_shell.dart:19-23` — the five bottom-nav destinations and their exact labels/
  icons (`Home`/`home_outlined`, `Invest`/`trending_up_outlined`, `Budgets`/`pie_chart_outline`,
  `Assistant`/`smart_toy_outlined`, `Settings`/`settings_outlined`) — the tour's slide order and
  icons should mirror these exactly so the tour reads as "here's what those five tabs do."
- `pubspec.yaml` — no animation/carousel package (no `lottie`, no `rive`, no `carousel_slider`) is a
  dependency today. This plan adds none; the tour is built from Flutter's own `PageView` +
  `AnimatedContainer`/`Transform`/`TweenSequence`, consistent with how the lock-screen shake and
  login-error shake were already built without a new dependency.
- `test/core/auth/auth_controller_test.dart`, `test/core/router/app_router_test.dart`,
  `test/core/auth/biometric_preference_test.dart` — existing test files this plan extends; no new
  top-level test directory needed for Steps 1-2's logic.
- `lib/core/theme/shared_preferences_provider.dart` — `sharedPreferencesProvider` throws
  `UnimplementedError` unless overridden. `onboardingStoreProvider` (Step 1) watches it, which makes
  `authControllerProvider` transitively depend on it too. Today's tests already override
  `authControllerProvider` directly (or go through `test_helpers/pump_app.dart`, which already
  overrides `sharedPreferencesProvider`), so nothing breaks — but any *new* test that reaches
  `authControllerProvider`/`apiClientProvider` without one of those two overrides will now throw.
- `test/features/security/security_screen_test.dart:88-89` — the established pattern for a mocktail
  `Mock...implements AuthController` with `state` stubbed; Step 4 should follow this same pattern
  rather than inventing a new fake style.
- Confirmed via `grep -r "PopScope\|WillPopScope" lib/`: **zero matches.** There is no existing
  precedent in this app for blocking the system back gesture — the consent gate relies entirely on
  the redirect listener, not a pop-blocking widget. Step 3's `PopScope` usage will be the first in
  this codebase.

**Explicitly out of scope (this plan):**
- **Live spotlight/coach-mark overlays on the real Dashboard/Budgets/etc. screens** — the user
  explicitly deferred this to "later." Do not add widget `GlobalKey`s, a coach-mark/portal
  mechanism, or any new dependency for it in this plan. Steps below should avoid decisions that
  would make that later phase harder (e.g. keep tour content/copy in a small data model that a
  future live-tour phase could plausibly reuse), but building it is not in scope.
- Showing the tour to existing users who registered before this ships (no backfill/migration —
  `OnboardingStore.isPending` returns `false` for any user id with no key, which is exactly every
  pre-existing account; see Step 1's revised design).
- A settings-screen "replay the tour" entry point — not requested; skip it unless the user asks.
- Any backend/API change — this is entirely a client-side, locally-persisted UI feature.

---

## Dependency graph

```
Step 1 (AuthState/AuthController/OnboardingStore/router gate + unit tests)  ─┐
                                                                              ├─ independent, parallel
Step 2 (Shared Penny + speech-bubble tour widgets, motion)                  ─┘

Step 3 (OnboardingScreen: 7 slides, PageView, wiring) ── depends on Steps 1 and 2

Step 4 (Widget tests + live visual QA pass, light/dark) ── depends on Step 3
```

**Recommended execution order:** Steps 1 and 2 in parallel (disjoint files — Step 1 touches
`lib/core/auth/*`, `lib/core/router/app_router.dart`, and `test/core/auth/`/`test/core/router/`;
Step 2 touches only new files under `lib/features/onboarding/models/` and
`lib/features/onboarding/widgets/`). Step 1's placeholder `OnboardingScreen` lives at
`lib/features/onboarding/screens/onboarding_screen.dart`, a third, disjoint new file — no conflict
with Step 2's `models/`/`widgets/` files. Step 3 after both merge. Step 4 last.

---

## Step 1 — Onboarding gate: `AuthState`, `AuthController`, `OnboardingStore`, router precedence

**Type:** Flutter/Dart, state + routing. **Model:** default. **Independent — no dependency on
other steps.**

**Context brief:** This is the plumbing that decides *whether* the tour shows, mirroring the
existing `consentsRequired` gate exactly but driven by a local `SharedPreferences` flag instead of
a server call — the tour is a client-only feature with nothing for the backend to enforce. The rule
that matters most: **only `register()` ever creates a pending-tour flag, and only for the account
it just created — but all three auth paths (`register()`, `login()`, `restoreSession()`) derive
`onboardingRequired` by *reading* that flag, not by hand-setting `true`/`false` per path.** This is
a deliberate revision from this plan's first draft, which had `login()`/`restoreSession()` always
hard-set `false` — that made the flag write-only (nothing ever read `hasSeen`), so a user who
registered and then force-quit mid-tour would silently lose it forever on next launch, with no way
to resume. Reading a per-user "pending" flag instead fixes that *and* still satisfies the actual
requirement — an account with no pending flag (because it existed before this feature shipped, or
already completed the tour) is never surprised by it, on `login()` or `restoreSession()` alike.

**Task list:**
1. Add a new file `lib/core/auth/onboarding_store.dart`, modeled on `biometric_preference.dart`
   but as a plain class (not a `StateNotifier` — `AuthController` needs synchronous read and async
   write access directly, not a watched provider):
   ```dart
   class OnboardingStore {
     OnboardingStore(this._prefs);
     final SharedPreferences _prefs;
     static const _keyPrefix = 'onboarding_pending_';

     /// True only between a successful `register()` and that account's next
     /// `completeOnboarding()` call — i.e. "this account has an unfinished tour."
     bool isPending(String userId) => _prefs.getBool('$_keyPrefix$userId') ?? false;

     Future<void> markPending(String userId) => _prefs.setBool('$_keyPrefix$userId', true);

     Future<void> clearPending(String userId) => _prefs.remove('$_keyPrefix$userId');
   }

   final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
     return OnboardingStore(ref.watch(sharedPreferencesProvider));
   });
   ```
   Key each entry by user id (not a single global flag) so the gate is correct per-account on a
   shared device. No key ever existing for a given user id is the mechanism that guarantees
   pre-existing accounts (registered before this feature shipped) are never gated — there is
   deliberately no backfill/migration step.
2. In `lib/core/auth/auth_state.dart`, add `onboardingRequired` (`bool`, default `false`) alongside
   `consentsRequired` — same shape: constructor param, field, `copyWith` param, doc comment
   explaining it's local-only (no backend concept of this gate, unlike `consentsRequired`).
3. In `lib/core/auth/auth_controller.dart`:
   - Add a fourth constructor dependency, `OnboardingStore _onboardingStore`. **Update the three
     existing direct `AuthController(...)` constructions in
     `test/core/auth/auth_controller_test.dart` (lines ~76-80, ~186-190, ~202-206) to pass it** —
     the file will not compile otherwise.
   - In `register()`: after building `user`, `await _onboardingStore.markPending(user.id)`, then set
     `onboardingRequired: true` in the resulting `AuthState` (this is the only place a pending flag
     is ever *created*).
   - In `login()` and `restoreSession()`: set `onboardingRequired: _onboardingStore.isPending(user.id)`
     (a synchronous read — `SharedPreferences.getBool` is not async) instead of hand-setting a
     literal `true`/`false`. This means a login or session-restore for an account with an unfinished
     tour resumes it; an ordinary account with no pending flag (never registered-and-interrupted)
     always gets `false`.
   - Add `Future<void> completeOnboarding() async { final id = state.user?.id; if (id != null)
     await _onboardingStore.clearPending(id); state = state.copyWith(onboardingRequired: false); }`
     — called by the tour screen on both "Get Started" and "Skip." Guard on `state.user?.id` being
     non-null the same way `refreshConsentStatus()` guards on `state.accessToken`.
   - Update `authControllerProvider`'s construction (~line 194) to pass
     `onboardingStore: ref.read(onboardingStoreProvider)`. Note this makes `authControllerProvider`
     transitively depend on `sharedPreferencesProvider` (via `onboardingStoreProvider`), which throws
     `UnimplementedError` unless overridden — today's tests already override `authControllerProvider`
     directly or go through `test_helpers/pump_app.dart` (which already overrides
     `sharedPreferencesProvider`), so nothing breaks, but keep this in mind if a new test reaches
     `authControllerProvider` without either override.
4. In `lib/core/router/app_router.dart`:
   - Add `GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen())` —
     import from `../../features/onboarding/screens/onboarding_screen.dart` (Step 3 creates the
     real file; for this step, create a minimal placeholder `OnboardingScreen` — a bare `Scaffold`
     with centered text `'Onboarding placeholder'` — purely so this step's route wiring and
     redirect logic compile and are independently testable before Step 3 lands).
   - Update `computeRedirect`'s doc comment and body: insert the new gate immediately after the
     `consentsRequired` check and before the final `loggingIn || ... → '/'` line:
     ```dart
     if (auth.consentsRequired) return matchedLocation == '/consent' ? null : '/consent';
     if (auth.onboardingRequired) return matchedLocation == '/onboarding' ? null : '/onboarding';
     if (loggingIn || matchedLocation == '/lock' || matchedLocation == '/consent' || matchedLocation == '/onboarding') return '/';
     ```
     Precedence order is now: `locked` > `consentsRequired` > `onboardingRequired` > shell —
     document this explicitly in the doc comment above the function, same style as the existing
     one.
5. Extend `test/core/auth/auth_controller_test.dart`: a fake/mock `OnboardingStore` (or a real one
   backed by `SharedPreferences.setMockInitialValues({})`, matching how other tests in this file
   fake dependencies), asserting: `register()` → `state.onboardingRequired == true` and the store now
   reports `isPending(userId) == true`; `login()`/`restoreSession()` → `onboardingRequired` mirrors
   whatever `isPending` returns (test both `true` and `false` cases, i.e. a fresh account with no
   prior key vs. one with a pending flag already set); `completeOnboarding()` → flips the flag `false`
   on state and clears the store's pending flag for that user id.
6. Extend `test/core/router/app_router_test.dart`'s `computeRedirect` test table with cases for
   `onboardingRequired: true` at various `matchedLocation`s, confirming it's beaten by `locked` and
   beats the shell fallback, and confirming `consentsRequired: true, onboardingRequired: true` still
   redirects to `/consent` first (consent wins).

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test test/core/auth/ test/core/router/
```

**Exit criteria:** `flutter analyze` clean, all touched tests green, `register()` always sets a
pending flag and the gate; `login()`/`restoreSession()` correctly mirror `OnboardingStore.isPending`
in both directions (never surprising an account with no pending flag, but correctly resuming one
that has it); `computeRedirect` precedence is `locked > consentsRequired > onboardingRequired >
shell` with a passing test for every ordering; navigating to `/` while `onboardingRequired` is true
bounces to the placeholder `/onboarding` screen (manually confirmed by temporarily forcing the flag
true in a debug print, or via the new unit tests — a full live register-flow check happens in
Step 4).

---

## Step 2 — Shared Penny + speech-bubble tour widgets

**Type:** Flutter UI, shared widgets. **Model:** default. **Independent of Step 1 — touches only
new files.**

**Context brief:** Build the reusable visual pieces the tour screen (Step 3) will assemble: an
animated Penny mascot presentation and a speech-bubble/text card, both driven by
`AppMotion`'s existing vocabulary and both reduced-motion-aware (per `context.reducedMotion`, the
same extension used by the chatbot/lock-screen/login-shake animations). No new package dependency.

**Task list:**
1. New file `lib/features/onboarding/models/tour_page.dart` — a small immutable data model:
   ```dart
   class TourPage {
     const TourPage({required this.icon, required this.title, required this.body});
     final IconData icon;
     final String title;
     final String body;
   }
   ```
   Deliberately minimal (icon + title + body) so Step 3 can compose real copy against it, and so a
   later live-tour phase could plausibly reuse the same content model against real widget targets
   instead of icons — noted as a nice-to-have, not a requirement to design around further.
2. New file `lib/features/onboarding/widgets/penny_avatar.dart` — `PennyAvatar` widget wrapping the
   existing `ClipRRect(borderRadius: 24) + Image.asset('assets/mascot.jpg', fit: BoxFit.cover)`
   pattern from `login_screen.dart`, parameterized by size, plus a continuous subtle idle "bob"
   (small vertical `Transform.translate` loop via an `AnimationController` +
   `Tween`/`CurvedAnimation` using `AppMotion.easeInOut`, repeating with `reverse: true`) — skip the
   repeating animation entirely (render static) when `context.reducedMotion` is true, matching how
   the rest of the app already gates implicit animations.
3. New file `lib/features/onboarding/widgets/speech_bubble.dart` — `SpeechBubble` widget: a rounded
   card (reuse existing card styling — check `GroupCard`/`icon_chip.dart` for the app's established
   corner-radius/elevation/border conventions before inventing new ones) with a small triangular
   "tail" pointing toward the mascot, containing a title + body `Text` styled through
   `Theme.of(context).textTheme` (never hand-picked font sizes, per the audit's `hero_metric_card`
   fix precedent). Entrance animation: a slide-up + fade-in (`AppMotion.easeOut`,
   `AppMotion.stateChange` duration) when the bubble's content changes (i.e. on page change), again
   skipped under `context.reducedMotion`.
4. Keep both widgets stateless from the outside (no dependency on go_router, Riverpod, or
   `OnboardingScreen` internals) so they're trivially unit-testable and reusable if a later phase
   wants them elsewhere.

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test test/features/onboarding/ 2>NUL || echo "no tests yet for these widgets — Step 3 adds screen-level coverage"
```

**Exit criteria:** `flutter analyze` clean, both widgets compile and render in isolation (a quick
manual `flutter run` smoke check dropping `PennyAvatar` and `SpeechBubble` into any existing debug
screen is enough — no dedicated widget test is required for this step since Step 4 covers them via
the full `OnboardingScreen`), idle-bob and entrance animations both respect `context.reducedMotion`.

---

## Step 3 — `OnboardingScreen`: the seven-slide tour, real copy, full wiring

**Type:** Flutter UI + routing integration. **Model:** default. **Depends on Steps 1 and 2.**

**Context brief:** Assemble Step 2's widgets and Step 1's gate into the real, shippable tour.
Content mirrors the bottom nav exactly (`app_shell.dart`'s five destinations, in their existing
order) bookended by a welcome slide and framed so the last slide's action reads as "enter the app,"
not "next page." Copy should sell what each tab *does for the user* (outcome-oriented), not
describe UI mechanics — same principle this workspace already applies to client-facing copy
elsewhere.

**Task list:**
1. Replace Step 1's placeholder `OnboardingScreen` with the real implementation at
   `lib/features/onboarding/screens/onboarding_screen.dart`:
   - A `PageView` (or `PageView.builder`) of 7 pages built from a `List<TourPage>` local to this
     screen:
     1. **Welcome** — `PennyAvatar` at a larger size, no bottom-nav icon; title "Hi, I'm Penny!";
        body introducing Penny as the user's guide to their money.
     2. **Home** (`Icons.home_outlined`) — dashboard overview: net worth, accounts, quick actions.
     3. **Invest** (`Icons.trending_up_outlined`) — portfolios, TFSA/RA, tracking growth.
     4. **Budgets** (`Icons.pie_chart_outline`) — setting budgets, goals, staying on track.
     5. **Assistant** (`Icons.smart_toy_outlined`) — asking Penny questions about their finances
        any time.
     6. **Settings** (`Icons.settings_outlined`) — security (PIN/biometric), privacy, data export.
     7. **Get started** — closing slide, no icon-tab framing; title "You're all set"; single
        prominent CTA button.
   - Each non-final page: `PennyAvatar` (smaller, consistent size) + `SpeechBubble` for that page's
     title/body, a page-dot indicator, a text "Skip" action (top-right, always visible except on
     the final page), and a "Next" button.
   - Final page: replace "Next" with a single "Get Started" `ElevatedButton` (primary CTA styling,
     consistent with the app's existing primary-button treatment).
   - Both "Skip" (from any page) and "Get Started" (final page only) call
     `ref.read(authControllerProvider.notifier).completeOnboarding()`. Do **not** manually navigate
     afterward — `computeRedirect`'s listener already reacts to `onboardingRequired` flipping false
     and routes to `/` on its own (same mechanism the consent screen already relies on).
   - Wrap the whole screen in `PopScope(canPop: false, ...)` so a system back-gesture can't dismiss
     the gate without going through Skip/Get Started. **Note: `grep -r "PopScope\|WillPopScope" lib/`
     returns zero matches today** — this app has no existing pop-blocking precedent (the consent
     gate relies entirely on the redirect listener), so this will be the first use of the pattern;
     don't assume there's an existing convention to match, just use `PopScope` directly.
2. Update the `GoRoute` import in `app_router.dart` if the placeholder's import path changes (it
   shouldn't, if Step 1 already pointed it at this file's final path).
3. Confirm slide order and copy against `app_shell.dart`'s destination order one more time before
   finalizing — the tour must not silently drift out of sync with the real tab order if that ever
   changes later (a short doc comment noting the coupling is enough, not a shared constant — don't
   over-engineer this).

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test
```

**Exit criteria:** `flutter analyze` clean, full test suite green (no regressions to the router/auth
tests from Step 1), a manual `flutter run -d chrome` walkthrough shows all 7 slides in order, Skip
from any page and Get Started from the last page both land on the dashboard, and re-registering
(or forcing `onboardingRequired` true again in a debug scenario) reliably reshows it — while an
ordinary login with an existing, already-onboarded account never shows it.

---

## Step 4 — Widget tests + live visual QA (light + dark)

**Type:** Testing + manual QA. **Model:** default. **Depends on Step 3.**

**Context brief:** Close the loop the same way the 2026-09-12 UI/UX audit session did: automated
tests for logic/structure, then a real browser-based visual pass via Chrome DevTools MCP for
things tests can't catch (contrast, animation feel, overflow on narrow layouts). Reuse the
already-solved gotchas from that session rather than rediscovering them.

**Task list:**
1. Add `test/features/onboarding/onboarding_screen_test.dart`: pump `OnboardingScreen` inside a
   `ProviderScope` overriding `authControllerProvider` with a mocktail `Mock...implements
   AuthController` with `state` stubbed — follow the exact pattern already established in
   `test/features/security/security_screen_test.dart:88-89`, don't invent a new fake style. Assert
   all 7 pages are reachable via `Next`/swipe, `Skip` calls `completeOnboarding()` from any page,
   `Get Started` only appears on the final page, and the page-dot indicator reflects the current
   page index.
2. Add a `computeRedirect`-level integration check if one doesn't already exist in
   `app_router_test.dart` from Step 1: simulate the exact sequence `register() → /onboarding →
   completeOnboarding() → /`.
3. Live visual QA: `flutter run -d chrome --web-port=8765` (or any free port), then via Chrome
   DevTools MCP — **before starting, check for an orphaned automation Chrome instance the same way
   the prior session did**
   (`Get-CimInstance Win32_Process -Filter "name = 'chrome.exe'" | Where-Object { $_.CommandLine
   -like '*chrome-devtools-mcp*' } | Stop-Process -Force` if `new_page`/`list_pages` errors with
   "The browser is already running"):
   - Register a fresh test account (a new, disposable email — do not reuse the shared
     `demo@financeapp.co.za` account, since it already exists and would never trigger the gate; if
     the backend isn't reachable from this machine per the prior session's finding, this whole
     sub-step is blocked the same way the dashboard/chart dark-mode check was — note that as a
     carry-over blocker rather than skipping verification silently).
   - Screenshot all 7 slides in **light** mode, then `emulate` with `colorScheme: dark` +
     `navigate_page` reload, repeat for **dark** mode — check contrast on the speech-bubble text
     over its card background in both themes, and confirm Penny's idle-bob animation and the
     slide entrance transition both render smoothly (no jank, no clipped bubble tail at any screen
     width including a narrow ~360px viewport).
   - If registering a fresh account is blocked by the same Tailscale/backend-reachability issue
     noted in the 2026-09-12 session's memory, do **not** temporarily edit `login()`/
     `restoreSession()` to force the flag (too easy to accidentally ship, or forget to revert
     before committing). Instead reach the screen via a debug-only path that never touches
     production auth code: either (a) temporarily point `main()`'s route at `/onboarding` directly
     (e.g. `initialLocation: '/onboarding'` in a scratch, uncommitted local edit reverted before the
     verification commands run), or (b) write a throwaway widget test that pumps `OnboardingScreen`
     directly (no router, no `AuthController` involved) and take its rendered output as the visual
     check instead of a live Chrome screenshot. Either way, confirm nothing from this workaround is
     part of the diff before Step 4's final commit.
4. Fix anything the visual pass surfaces (contrast, overflow, animation glitch) in this same step
   before merging — don't defer known-bad visuals to a future session.

**Verification:**
```bash
cd "C:\Fynbos Creative Master\02_Clients\Piggybank"
flutter analyze
flutter test
```
Plus the manual Chrome DevTools MCP screenshot pass described above (both color schemes, narrow
viewport included).

**Exit criteria:** `flutter analyze` clean, full test suite green, all 7 slides confirmed clean in
both light and dark mode with no contrast/overflow/animation issues, merge `penny-onboarding-tour`
→ `master` with a `--no-ff` merge commit (matching the established pattern from the prior
animation/audit-fixes branches), re-verify `flutter analyze`/`flutter test` on merged `master`.

---

## Anti-patterns to avoid (all steps)

- Don't reach for a coach-mark/spotlight package or `GlobalKey`-based overlay system — that's the
  explicitly deferred Phase 2, not this plan.
- Don't let `login()` or `restoreSession()` hard-set a literal `onboardingRequired: true`/`false` —
  both must derive it from `OnboardingStore.isPending(userId)`, and only `register()` ever calls
  `markPending`. Hard-coding `false` in those two paths is the specific bug this plan's own first
  draft had (caught in adversarial review) — it silently loses an interrupted tour forever.
- Don't hand-type font sizes/curves/durations in the new widgets — route through
  `Theme.of(context).textTheme` and `AppMotion`, per this app's established convention.
- Don't add a new animation/carousel package — `PageView` + the existing motion primitives are
  sufficient, and the last audit session's guidance was to scope tightly to what's verifiable
  without new dependencies.
- Don't skip the reduced-motion gate on the new idle-bob/entrance animations — every other implicit
  animation in this app was retrofitted with it specifically because it was missed the first time.
