# Plan: Lock Screen Logout Escape Hatch

## Summary
The app-lock screen (`/lock`) can reach a state with no working unlock method — no biometric hardware/enrollment and no PIN set (or a forgotten PIN) — and currently offers zero way out. This is a real production lockout hit during on-device smoke testing: user logs in, app restarts (or is backgrounded and killed), `restoreSession()` unconditionally re-locks, biometric auto-attempt fails silently on a device with nothing enrolled, and there is no PIN to fall back to (or the tester doesn't know one that was set in an earlier session). The fix adds a "Log out" escape hatch to `LockScreen`, always available, that routes the user back to `/login` via the existing `logout()` flow — without weakening the "never silently unlock" invariant that a prior fix deliberately put in place.

## User Story
As a Piggybank user whose device can't complete biometric unlock and who has no PIN set (or has forgotten it),
I want a way to log out from the lock screen,
So that I can get back into the app via email/password instead of being permanently stuck.

## Problem → Solution
**Current**: `LockScreen` shows either a biometric prompt button or PIN entry, with no other action available. If biometric fails/unavailable and `hasPin` is false, the screen renders nothing actionable — confirmed by the existing test `'no biometric hardware and no PIN set: never silently unlocks'` in `test/features/auth/screens/lock_screen_test.dart:173-189`, which asserts exactly this dead-end state as intentional (no silent unlock) but never asserts an escape route.
**Desired**: `LockScreen` always shows a "Log out" text button (below the biometric or PIN UI). Tapping it calls the already-existing `authControllerProvider.notifier.logout()`, which clears the stored refresh token and sets `AuthState.unauthenticated()`; the pre-existing `_RouterRefreshListenable` + `computeRedirect` (`app_router.dart:79`) already sends `unauthenticated` straight to `/login` with no changes needed there.

## Metadata
- **Complexity**: Small
- **Source PRD**: N/A
- **PRD Phase**: N/A
- **Estimated Files**: 2 (1 implementation, 1 test file update)

---

## UX Design

### Before
```
┌─────────────────────────────┐
│      Piggybank is locked    │
│                              │
│         (fingerprint)       │
│   Tap to unlock with         │
│   biometrics                │
│                              │
│   [no PIN link if hasPin    │
│    is false — dead end]     │
└─────────────────────────────┘
```

### After
```
┌─────────────────────────────┐
│      Piggybank is locked    │
│                              │
│         (fingerprint)       │
│   Tap to unlock with         │
│   biometrics                │
│                              │
│   Use PIN instead (if hasPin)│
│   Log out                   │  ← new, always shown
└─────────────────────────────┘
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Lock screen, biometric-button state | No secondary action beyond optional "Use PIN instead" | Adds "Log out" text button below existing content | Always visible regardless of `_hasPin` |
| Lock screen, PIN-entry state | "Use biometrics instead" link only when biometric preference is on | Adds "Log out" text button below existing content | Always visible regardless of biometric preference |
| Tapping "Log out" | N/A | Calls `authControllerProvider.notifier.logout()`; router redirects to `/login` | Mirrors what Settings' delete-account flow already does after `deleteAccount()` (`security_screen.dart:116`) |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/features/auth/screens/lock_screen.dart` | 1-152 | The file being changed — full widget state machine |
| P0 | `lib/core/auth/auth_controller.dart` | 111-116, 185-187 | `logout()` already does exactly what's needed; `lockApp()` shows the mirrored `state.isAuthenticated` guard style |
| P0 | `lib/core/router/app_router.dart` | 56-84 | Confirms `logout()` alone is sufficient — no router changes needed. `computeRedirect` already sends `unauthenticated` → `/login` from `/lock` |
| P1 | `test/features/auth/screens/lock_screen_test.dart` | 173-189 | The existing test documenting the dead-end state this plan fixes; must be updated, not just left passing |
| P1 | `lib/features/settings/screens/security_screen.dart` | 92-118 | Existing pattern for a session-ending action from a screen (`_attemptDeleteAccount` → `logout()`) — mirror its simplicity, not its confirmation dialog (see GOTCHA below) |
| P2 | `test/core/router/app_router_test.dart` | 20-27 | Confirms `unauthenticated` redirects to `/login` from any location including `/lock` — no new router test needed, existing coverage already proves this half of the flow |

## External Documentation
No external research needed — feature uses established internal patterns (existing `logout()`, existing router redirect, existing `TextButton` styling already used elsewhere on this same screen for "Use PIN instead"/"Use biometrics instead").

---

## Patterns to Mirror

### WIDGET_ACTION_BUTTON (TextButton style already used on this screen)
```dart
// SOURCE: lib/features/auth/screens/lock_screen.dart:118-124
if (ref.read(biometricPreferenceProvider)) ...[
  const SizedBox(height: 16),
  TextButton(
    onPressed: () => setState(() => _showPinEntry = false),
    child: const Text('Use biometrics instead'),
  ),
],
```

### CONTROLLER_ACTION_FROM_SCREEN (calling an AuthController method from a screen)
```dart
// SOURCE: lib/features/settings/screens/security_screen.dart:114-117
await _run(() async {
  await ref.read(accountApiProvider).deleteAccount(password);
  await ref.read(authControllerProvider.notifier).logout();
});
```
Note: `_attemptDeleteAccount` wraps this in a confirmation dialog because deleting the account is destructive. Logging out from a lock screen is **not** destructive (the session token is discarded locally; the account and server-side session simply require a fresh login) — no confirmation dialog needed, matching how "Use PIN instead" / "Use biometrics instead" are plain unconfirmed taps on this same screen.

### STATE_NOTIFIER_LOGOUT (what the button ends up triggering — already correct, no change here)
```dart
// SOURCE: lib/core/auth/auth_controller.dart:111-116
Future<void> logout() async {
  final refreshToken = await _secureStorage.readRefreshToken();
  await _authApi.logout(refreshToken);
  await _secureStorage.clearRefreshToken();
  state = AuthState.unauthenticated();
}
```

### TEST_STRUCTURE (widget test pattern for this exact screen)
```dart
// SOURCE: test/features/auth/screens/lock_screen_test.dart:173-189
testWidgets('no biometric hardware and no PIN set: never silently unlocks', (tester) async {
  authController.state = const AuthState(
    status: AuthStatus.authenticated,
    accessToken: 'token',
    locked: true,
    user: User(id: 'u1', email: 'a@b.com', fullName: null, role: 'user', isActive: true, hasPin: false),
  );
  when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
  when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

  await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
  await tester.pumpAndSettle();

  expect(authController.state.locked, true);
  expect(find.text('Use PIN instead'), findsNothing);
  expect(find.byType(TextField), findsNothing);
});
```
This existing test's assertions (`locked` still true after render, no PIN affordance) stay correct and must NOT change — only add a new assertion/new test for the "Log out" button's presence and behavior, since logging out is a distinct exit from the *screen*, not a silent unlock of the *lock state*.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/features/auth/screens/lock_screen.dart` | UPDATE | Add a "Log out" `TextButton` visible in both the biometric-button branch and the PIN-entry branch of `build()`; wire it to `ref.read(authControllerProvider.notifier).logout()` |
| `test/features/auth/screens/lock_screen_test.dart` | UPDATE | Add test(s) asserting the "Log out" button is present in the no-unlock-method dead-end state and that tapping it unauthenticates |

## NOT Building
- No changes to `AuthController.restoreSession()`'s always-lock-on-restore behavior — that is a deliberate security decision for a finance app (see its doc comment) and is not the bug.
- No "Forgot PIN" self-service reset flow (would require a new backend endpoint / re-auth-by-email flow) — logging out and back in with password already achieves the same recovery outcome via existing, tested infrastructure.
- No changes to `computeRedirect`/`app_router.dart` — already correctly sends `unauthenticated` to `/login` from `/lock`, proven by existing `app_router_test.dart` coverage.
- No confirmation dialog before logout on this screen — logging out here is non-destructive and matches the screen's existing unconfirmed-tap pattern ("Use PIN instead", "Use biometrics instead").
- No change to biometric-preference defaulting or `restoreSession`'s unconditional `locked: true` — out of scope; the fix is the escape hatch, not the locking policy.

---

## Step-by-Step Tasks

### Task 1: Add "Log out" button to the biometric-button branch
- **ACTION**: In `lock_screen.dart`'s `build()`, inside the `else` branch that renders the fingerprint icon + "Tap to unlock with biometrics" (currently lines ~125-144), add a `TextButton` below the existing `if (_hasPin) ...` block that calls logout.
- **IMPLEMENT**:
  ```dart
  const SizedBox(height: 16),
  TextButton(
    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
    child: const Text('Log out'),
  ),
  ```
- **MIRROR**: `WIDGET_ACTION_BUTTON` pattern above (same `TextButton` shape as "Use biometrics instead").
- **IMPORTS**: None new — `authControllerProvider` is already imported at the top of the file.
- **GOTCHA**: Don't gate this on `_hasPin` or `_prompting` — place it only in the non-`_prompting`, non-`_showPinEntry` branch (i.e., the same branch as the fingerprint icon), consistent with where "Use PIN instead" already lives, so it doesn't appear mid-spinner.
- **VALIDATE**: `flutter analyze` clean; widget test (Task 3) finds `find.text('Log out')` in this branch.

### Task 2: Add "Log out" button to the PIN-entry branch
- **ACTION**: In the `if (_showPinEntry) ...` branch (currently lines ~104-124), add the same `TextButton` after the existing conditional "Use biometrics instead" button (or in its place when that link isn't shown, i.e. when biometric preference is off).
- **IMPLEMENT**:
  ```dart
  const SizedBox(height: 16),
  TextButton(
    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
    child: const Text('Log out'),
  ),
  ```
  Place this unconditionally at the end of the `if (_showPinEntry)` block, after the existing `if (ref.read(biometricPreferenceProvider)) ...` block — so it always renders whether or not the biometric fallback link is shown.
- **MIRROR**: Same `WIDGET_ACTION_BUTTON` pattern.
- **IMPORTS**: None new.
- **GOTCHA**: Leave it always tappable even while `_pinSubmitting` is true — `unlockWithPin`'s `on ApiError catch` returning `false` after a `logout()` has already run is harmless (the screen will already have redirected away by the time any late response arrives), and `_submitPin` already guards `if (!mounted) return;`.
- **VALIDATE**: Widget test (Task 3) finds `find.text('Log out')` in the PIN-entry branch too.

### Task 3: Add widget tests
- **ACTION**: In `test/features/auth/screens/lock_screen_test.dart`, add two new `testWidgets` cases; confirm the existing "never silently unlocks" test's assertions still pass unchanged.
- **IMPLEMENT**:
  ```dart
  testWidgets('no biometric hardware and no PIN set: "Log out" is available and works', (tester) async {
    authController.state = const AuthState(
      status: AuthStatus.authenticated,
      accessToken: 'token',
      locked: true,
      user: User(id: 'u1', email: 'a@b.com', fullName: null, role: 'user', isActive: true, hasPin: false),
    );
    when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
    when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);
    when(() => mockSecureStorage.readRefreshToken()).thenAnswer((_) async => 'refresh');
    when(() => mockSecureStorage.clearRefreshToken()).thenAnswer((_) async {});
    when(() => mockAuthApi.logout(any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsOneWidget);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(authController.state.isAuthenticated, false);
  });

  testWidgets('PIN entry state: "Log out" is available alongside PIN entry', (tester) async {
    authController.state = const AuthState(
      status: AuthStatus.authenticated,
      accessToken: 'token',
      locked: true,
      user: User(id: 'u1', email: 'a@b.com', fullName: null, role: 'user', isActive: true, hasPin: true),
    );
    await prefs.setBool('biometric_enabled', false);

    await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsOneWidget);
  });
  ```
- **MIRROR**: `TEST_STRUCTURE` pattern above — same `MockAuthApi`/`MockSecureStorage`/`buildScreen` fixtures already set up in this file's `setUp()`.
- **IMPORTS**: None new — `mockAuthApi`, `mockSecureStorage` already declared/instantiated in the file's `setUp()`.
- **GOTCHA**: `authController` here is the real `AuthController` instance built in `setUp()` with `mockAuthApi`/`mockSecureStorage`/`mockLocalAuth` — its `logout()` calls through to those mocks, so they must be stubbed (as shown) or the test throws a `MissingStubError` from mocktail.
- **VALIDATE**: `flutter test test/features/auth/screens/lock_screen_test.dart` — all cases pass, including the pre-existing 5 tests unmodified.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| Log out from biometric-button branch (no hardware, no PIN) | Tap "Log out" | `authController.state.isAuthenticated == false` | Yes — the exact dead-end this plan fixes |
| Log out from PIN-entry branch (has PIN, biometric off) | Button present | `find.text('Log out')` → `findsOneWidget` | No — secondary coverage of the same button in the other branch |
| Existing "never silently unlocks" test | No hardware, no PIN | `locked` stays `true`, no PIN field, no "Use PIN instead" | Regression guard — must still pass unchanged |

### Edge Cases Checklist
- [x] No biometric hardware + no PIN (the reported bug) — covered by Task 3's first new test
- [x] Has PIN but forgot it (PIN-entry branch always reachable via "Use PIN instead" when `_hasPin`) — covered by Task 3's second new test proving "Log out" is present there too
- [ ] Concurrent access — N/A, single-device local state only
- [ ] Network failure calling `logout()`'s `_authApi.logout(refreshToken)` — not newly introduced by this change; matches existing behavior used identically from Settings' delete-account flow. Out of scope to change here.
- [x] Permission denied — N/A, no new permissions

---

## Validation Commands

### Static Analysis
```bash
flutter analyze
```
EXPECT: Zero new type/lint errors (repo's existing warnings, if any, unchanged).

### Unit Tests
```bash
flutter test test/features/auth/screens/lock_screen_test.dart test/core/auth/auth_controller_test.dart test/core/router/app_router_test.dart
```
EXPECT: All pass, including the 2 new cases and the unmodified 5 pre-existing `lock_screen_test.dart` cases.

### Full Test Suite
```bash
flutter test
```
EXPECT: No regressions anywhere else in the suite.

### Manual Validation
- [ ] On a real device (or emulator) with no biometric enrolled and no PIN set: force `restoreSession()` to run (kill and reopen the app after a valid login), confirm the lock screen shows "Log out", tap it, confirm you land on `/login` and can log back in with email/password.
- [ ] With a PIN set but biometric off: confirm "Log out" also appears next to the PIN boxes and works the same way.
- [ ] With biometric on and working: confirm "Log out" is reachable after tapping into either the biometric-button state or "Use PIN instead", without needing biometrics to succeed first.

---

## Acceptance Criteria
- [ ] All tasks completed
- [ ] All validation commands pass
- [ ] Tests written and passing
- [ ] No type errors
- [ ] No lint errors
- [ ] Matches UX design above

## Completion Checklist
- [ ] Code follows discovered patterns (`TextButton` styling matches existing "Use PIN instead"/"Use biometrics instead")
- [ ] Error handling matches codebase style (no new error handling needed; `logout()` unchanged)
- [ ] Logging follows codebase conventions (no logging framework used elsewhere in this file; none added)
- [ ] Tests follow test patterns (`lock_screen_test.dart`'s existing `buildScreen`/mock fixtures reused)
- [ ] No hardcoded values
- [ ] Documentation updated — update `lock_screen.dart`'s class doc comment (currently describes the biometric/PIN state machine only) to mention the logout escape hatch
- [ ] No unnecessary scope additions (no "Forgot PIN" flow, no `restoreSession` policy change)
- [ ] Self-contained — no questions needed during implementation

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| A user taps "Log out" reflexively while a biometric prompt or PIN check is in flight | Low | Low | `logout()` is safe here; any late PIN/biometric response after logout is a no-op against an already-unauthenticated state, and `_submitPin` already guards `if (!mounted) return;` |
| Adding a visible "Log out" makes it too easy to accidentally sign out of a finance app | Low | Low | It's a deliberate, separately-labeled `TextButton` below the primary unlock action, matching the same low-prominence styling as the existing optional links on this screen |

## Notes
This closes out the exact scenario from the physical-device smoke test: email login succeeded, app was restarted, `restoreSession()` re-locked, no PIN had been set (or was unknown to the tester), biometric wasn't available/enrolled, and there was no way back in short of clearing local app storage. The immediate workaround (clear app storage on the device) unblocks the user right now without any code change; this plan is the permanent fix so it can't happen again to any user.
