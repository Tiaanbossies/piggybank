# Next goal: friends & family beta

Agreed 2026-10-05 in an interview with Tiaan. Supersedes nothing: it follows on from
`daily-driver-sprint.md`, whose success metrics become the gate for the beta.

> **Paused 2026-10-07.** The savings-target / cost-cutting goal (`cost-cutting-plan.md`)
> now comes first. Phase A's UX items are shipped (1.0.6+7). Phase B and the
> ~2026-11-23 invite date wait until that plan is done, so the date will move.

## Goal

**By mid–late November 2026 (target invite date ~2026-11-23), 3–5 Android friends & family
are using Piggybank, and it has stopped being a chore for Tiaan first.**

Time budget: a few hours a week, alongside Fynbos client work. Small sprints.

## Where we are (2026-10-05)

- v1.0.4+5 installed. Daily use is **on and off**.
- Main reason for skipped days: **it feels like a chore**. The pain points are the
  home/overview screen, navigation, and the add/confirm flows.
- The filter-report check (`would_drop_real`) is still outstanding.

## Phase A: make it a non-chore for Tiaan (Oct)

What "done" looks like is **one-tap review**: new transactions arrive pre-filled (category,
account, amount) and Tiaan confirms each with one tap or swipe.

- One-tap or swipe confirm on the pending queue (no form unless something is wrong).
- Home/overview: today's spend and "N new to review" at a glance.
- Navigation: cut taps to the common destinations.
- Read the filter-report. If `would_drop_real == 0`, enforce the filter so junk stops
  reaching the queue.

**Gate:** the original daily-driver metrics. 14 consecutive days of use, ≥80%
auto-captured, <1 min/day.

## Phase B: beta plumbing (Nov)

A tester has to get value without Tiaan's help:

- **Easy install:** a public download link or Play Console internal testing. Today's
  `/downloads` is Tailscale-only, so testers can't reach it.
- **Smooth onboarding:** sign-up, detection consent, notification access and first
  accounts, all without hand-holding.
- **Auto-capture for their banks:** collect sample SMS/notifications from each tester's
  bank before invites, and extend parsing and the sender allowlist to cover them.
- **In-app feedback channel:** report a bug or idea from inside the app.
- **Everyone gets Pro free** for the beta. Pricing is decided after it.

## Phase C: beta waves

- **Wave 1, ~2026-11-23:** 3–5 Android testers.
- **Wave 2, later:** iPhone testers in **manual mode**. iOS can't read SMS or other apps'
  notifications, so they get manual entry. This needs an iOS build path (Mac or cloud
  CI) and an Apple Developer account ($99/yr) for TestFlight. That cost is deliberately
  off wave 1's critical path.

## How we'll know the beta worked

1. **Testers keep using it:** most are still active after 2–3 weeks without nagging.
2. **They'd pay for it:** asked directly at the end, since everyone is on free Pro.
   Also check their Pro-feature usage as a signal.

## Out of scope for now

Play Store public release, email detection, a web app, and paywall testing.
