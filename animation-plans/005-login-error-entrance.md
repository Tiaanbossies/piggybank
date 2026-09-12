# 005 — Grow-in the login error message instead of popping it

- **Status**: TODO
- **Commit**: 8a264ab
- **Severity**: LOW
- **Category**: Missed opportunities (feedback) / Purpose & frequency (preventing a jarring change)
- **Estimated scope**: 1 file

## Problem

`lib/features/auth/screens/login_screen.dart:100-102` shows the login error text with a plain
conditional — it pops in/out instantly, shoving the "Log in" button below it down without warning:

```dart
// current
if (_error != null) ...[
  const SizedBox(height: 16),
  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
],
```

No test file exists for `login_screen.dart` in `test/`, so there is no existing test suite to keep
passing for this change — verification is feel-check only plus `flutter analyze`.

## Target

Wrap the conditional block in `AnimatedSize` + `AnimatedOpacity` so the text grows into the layout
rather than shoving it, using `AppMotion.stateChange` (200ms) for the size and a slightly shorter
150ms for the opacity fade so the text is visible before the row has fully finished growing.

```dart
// target
AnimatedSize(
  duration: AppMotion.stateChange,
  curve: Curves.easeOut,
  alignment: Alignment.topCenter,
  child: _error == null
      ? const SizedBox(width: double.infinity)
      : Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AnimatedOpacity(
            opacity: _error == null ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ),
),
```

This replaces the `if (_error != null) ...[ SizedBox(height: 16), Text(...) ]` block in place —
`AnimatedSize` always keeps a child mounted (a zero-height `SizedBox` when there's no error) so it
has something to animate the height *from* when an error first appears.

## Repo conventions to follow

- Import `AppMotion` from `lib/core/theme/app_motion.dart` (plan 001). If plan 001 has not landed,
  stop and land it first.
- The surrounding `Column`'s `crossAxisAlignment: CrossAxisAlignment.stretch` (present in this
  screen's `Column`, confirmed at the top of the `build()` method) means `SizedBox(width: double.infinity)`
  is the correct zero-state placeholder — do not use a bare `SizedBox.shrink()`, which would collapse
  width too and change the stretch behavior of the column when transitioning.

## Steps

1. Confirm `lib/core/theme/app_motion.dart` exists (plan 001). If missing, stop.
2. In `lib/features/auth/screens/login_screen.dart`, add
   `import '../../../core/theme/app_motion.dart';` to the imports.
3. Replace the `if (_error != null) ...[ const SizedBox(height: 16), Text(_error!, ...) ],` block
   (lines 100-102) with the `AnimatedSize`/`AnimatedOpacity` version shown in "Target".

## Boundaries

- Do NOT touch the email/password fields, the visibility-toggle `IconButton`, or the submit button
  below this block.
- Do NOT add this same pattern to `register_screen.dart`, `forgot_password_screen.dart`, or
  `reset_password_screen.dart` — those were not part of the audited finding; this plan is scoped to
  `login_screen.dart` only.
- If a step doesn't match the code you find (drift since commit `8a264ab`), STOP and report instead
  of improvising.

## Verification

- **Mechanical**: `flutter analyze` (0 issues). No test file exists for this screen to run.
- **Feel check**: run the app, go to Login, submit with a wrong password, and confirm:
  - The error text grows in below the password field over ~200ms, with its own fade catching up
    slightly faster (150ms) so it's legible before the row finishes expanding.
  - The "Log in" button is pushed down smoothly, not instantly.
  - Clearing the error (submitting successfully, or navigating away and back) doesn't leave a stray
    gap — the `SizedBox(width: double.infinity)` zero-state collapses back to no height.
  - In DevTools (Animations panel), set playback to 10% and confirm no jump/flash mid-transition.
- **Done when**: `flutter analyze` is clean and the feel check above holds.
