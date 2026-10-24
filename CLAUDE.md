# CLAUDE.md: piggybank-app

Flutter app for Piggybank, a South African personal-finance tracker with an AI assistant ("Penny"). This is one of two repos; the FastAPI backend is the sibling `../piggybank-backend`. Workspace map: `../CLAUDE.md`.

**Start here:** `STATUS.md` is the one place that says where the project stands (shipped state, goals, open threads). Read it before planning anything. `DESIGN.md` is the design direction.

## Stack

- Flutter, Dart `^3.13`. State: `flutter_riverpod`. Routing: `go_router`. HTTP: `dio`.
- Features live in `lib/features/<name>/` (providers, data, screens); shared code in `lib/core/` and `lib/shared/`.
- The app talks to the backend over `/api` (`lib/core/api/api_config.dart`). Tests: `test/` (unit, widget, `test/goldens/` screenshots).

## Commands

```bash
flutter pub get
flutter analyze
flutter test
```

Release: `scripts/build_release.sh`, then `scripts/publish_release.sh` (publishes to the VPS, so it needs the host and Tiaan's go-ahead).

## Do not

- **Never run `dart format` on `lib/`.** The repo is not format-clean; it once rewrote 136 files.
- **Never touch `android/key.properties`, keystores or `../ops/`.** Release signing and symbols live there. Do not open, print or move them.
- Edit `pubspec.yaml` with `sed`, not PowerShell `Set-Content` (it adds a BOM and mangles em-dashes).
- Do not hand-edit `build/`, `.dart_tool/`, `android/.gradle` or `.idea/`; they are generated and ignored.
- Use only the four Penny cutouts in `assets/penny/` for mascot art. The Gemini source art in `assets/Gemini Mascot Images/` is git-ignored, so it has no git backup; keep a copy outside the repo.
- Money is ZAR. `formatZAR` uses U+00A0 (no-break) spaces, so test literals must too.
- Do not deploy, push, or message the host without an explicit yes. Remote writes are Tiaan's.

## Gotchas

- Flutter tests: set `TMP`/`TEMP` to `F:\Templutter` (the C: drive is near-full).
- Goldens pin the clock to 2026-10-15 10:00 via `withClock`/`testShot`; the harness is `test/goldens/screenshot_harness.dart`.
- Release builds can run out of memory; the workaround is in `STATUS.md` §5.
- `.gitattributes` enforces LF. Use `git -c core.autocrlf=false` if you still see CRLF noise.
- `privacy-policy-site/` is its own nested git repo (ignored here).

## Docs map

| Where | What |
|---|---|
| `STATUS.md` | Current state, goals, open threads, gotchas |
| `DESIGN.md` | Design direction |
| `QA_FINDINGS.md` | Living QA log; many plans refer to it, so it stays at the root |
| `docs/` | Design notes, scope docs, `qa/`, `research/`, `ux-rework/`, `visual-rework/` |
| `docs/archive/` | Finished session reports and old plans (history only; old QA screenshots live in git history) |
| `plans/` | Implementation plans, one per piece of work |
| `reviews/` | Dated reviews and decisions |
| `docs/BRANCHES.md` | Parked branches worth keeping, with how to resume them |
