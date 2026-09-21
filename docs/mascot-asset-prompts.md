# Penny mascot — visual-asset opportunity audit & Gemini prompts

Read-only audit (no code/assets changed) of where the Piggybank mascot could use
pose variation, plus ready-to-paste image-generation prompts. Written after
reading `DESIGN.md`, `assets/mascot.jpg`, and
`lib/features/onboarding/widgets/penny_avatar.dart`.

## Finding

`DESIGN.md`'s own note that a mascot asset is still outstanding is **stale** —
`assets/mascot.jpg` already exists and is a polished, on-brand 3D render. Per
`DESIGN.md`, app iconography is deliberately Material Symbols in icon-chips,
not a bespoke icon set, so custom-icon-generation ideas are NOT VALUABLE here —
this audit is scoped to mascot pose variation only.

**Base asset described:** a 3D-rendered, matte pastel-pink piggy bank, seated in
a friendly 3/4 front-right pose, soft rounded features, closed happy-smile
mouth, simple dot eyes with thin arched brows, a green leaf/sprout-embossed
coin inserted in a top coin-slot, on a plain warm off-white studio background
with soft even lighting and a subtle contact shadow.

**Gap:** the same static `assets/mascot.jpg` is reused with zero pose variation
across 6+ screens — Login, Register, Lock, Forgot password, Reset password, and
every onboarding tour page (see `penny_avatar.dart`).

## Prompts

### 1. Welcoming (Login / Register)

```
A single 3D-rendered piggy bank character, matte pastel pink, seated in a friendly
3/4 front-right pose, one front foot raised slightly as if waving hello, rounded
simple features, closed happy-smile mouth, small dot eyes with thin arched
eyebrows raised in a welcoming expression, a green coin embossed with a small
leaf/sprout icon inserted upright in a coin-slot on its back/head, plain warm
off-white studio background, soft even studio lighting, subtle soft contact
shadow beneath, no text, no other objects, square crop, high detail, consistent
with a prior reference render of the same character seated and smiling.
```

### 2. Sleeping (Lock screen)

```
The same 3D-rendered piggy bank character, matte pastel pink, lying curled on
its side in a restful sleeping pose, eyes closed with small curved sleep lines,
a faint closed-mouth smile, ears relaxed downward, the green leaf-embossed coin
still visible upright in its coin-slot, plain warm off-white studio background,
soft even studio lighting, subtle soft contact shadow beneath, no text, no
"Zzz" graphic, no other objects, square crop, high detail, consistent with a
prior reference render of the same character.
```

### 3. Thinking (Forgot/Reset password)

```
The same 3D-rendered piggy bank character, matte pastel pink, seated in a 3/4
front-right pose, head tilted slightly, one front foot raised to touch near its
chin in a "thinking" gesture, eyes looking upward and to the side, one eyebrow
raised, small closed-mouth curious expression, the green leaf-embossed coin
upright in its coin-slot, plain warm off-white studio background, soft even
studio lighting, subtle soft contact shadow beneath, no text, no thought-bubble
graphic, no other objects, square crop, high detail, consistent with a prior
reference render of the same character.
```

### 4. Celebrating (flagged: goal-completion, no UI slot yet)

```
The same 3D-rendered piggy bank character, matte pastel pink, standing on its
hind legs in a joyful celebratory pose, front legs raised up in a small cheer,
eyes closed in a big happy expression, wide closed-mouth smile, ears perked up,
the green leaf-embossed coin upright in its coin-slot, a few small green
confetti-leaf shapes scattered around it in the air, plain warm off-white
studio background, soft even studio lighting, subtle soft contact shadow
beneath, no text, square crop, high detail, consistent with a prior reference
render of the same character.
```

## Integration notes

- `PennyAvatar` (`lib/features/onboarding/widgets/penny_avatar.dart:52`)
  hardcodes `assets/mascot.jpg` — needs an optional `assetPath` param
  (default to the existing file) so Login/Register/Lock/Forgot/Reset/onboarding
  can each pass their own pose.
- Prompt 4's celebration pose has no home yet: `Goal` already models
  `GoalStatus.completed` (`lib/features/goals/models/goal.dart:3`), but
  `goals_screen.dart` has no completion banner/UI to show it — a separate small
  planning/implementation pass, deliberately not started here.

## Status

No files modified as part of this audit — prompt-writing/planning deliverable
only. Next step, when picked up: generate the four images via Gemini, then wire
the `assetPath` param and pick pose-per-screen.
