# Security & Privacy — public trust-page copy

Drafted 2026-08-31, per the Piggybank competitive-analysis report's #3 recommendation
("close the institutional-trust gap with what's actually true"). This is copy for a future
public-facing Security & Privacy page (linked from the Play Store listing and/or an in-app
Settings row) — **not yet wired into the app or published anywhere.**

**Every claim below is grounded in something already built and verified in this session**, per
the same evidence discipline the competitive report was held to. Nothing here is aspirational.

---

## Draft copy

```
Your data, your control

Piggybank is built for the financial details you'd hesitate to hand to just
any app — your accounts, your TFSA, your net worth. Here's exactly what that
means in practice.

Locked behind your own biometrics
Unlock with your fingerprint, face, or a PIN — your choice, and you can
change it any time. Your biometric data is encrypted and stored locally on
your device. It never reaches our servers, because we never need it to.

You can leave, and take everything with you
Export a full copy of your data — accounts, transactions, budgets, goals —
whenever you want, from Settings > Security. If you want to delete your
account, that's one tap away too: it's permanent, it's complete, and it's
entirely your call.

Built with POPIA in mind
Piggybank is designed around South Africa's Protection of Personal
Information Act from the ground up, not bolted on after the fact.

We're a small, independent app
Piggybank isn't backed by a bank or a listed financial group — it's built by
one person who wanted the tool to exist. That means no ad-tracking business
model built into the product, and no third party you didn't choose getting a
look at your financial life.
```

---

## Deliberately excluded — and why

**No claim about encryption in transit.** `docs/security-audit.md`'s Critical finding #1 is
still open: the shipped app talks to the backend over plain HTTP by default
(`api_config.dart`'s `http://100.121.165.7:8000/api`), with Caddy's TLS termination sitting on
a port the app never actually calls. The user has acknowledged this as a deferred decision
(Tailscale-as-transport-security, no public HTTPS today), but "your data is encrypted in
transit" would be a false claim on a public page as the app is currently configured. **Do not
add that language until the Critical finding is actually resolved** (Caddy in front of the
real request path, or the Tailscale-only model is deliberately kept — either way, the public
copy has to match the real transport, not the aspiration).

**No FSCA/regulatory language.** Piggybank isn't a registered Financial Services Provider and
doesn't hold client funds the way EasyEquities does — claiming FSCA-adjacent credibility would
be the exact "unearned trust signal" the competitive report warned against. If Piggybank ever
needs FSP registration (e.g. for advice-adjacent features), that's a real compliance
conversation, not copy to write ahead of it.

**No "bank-grade security" or similar unverifiable superlative.** Every claim above traces to
a specific screen or backend behavior verified this session (`security_screen.dart`, the
data-export/delete-account flows, `docs/compliance-foundation.md`'s POPIA framing). Nothing
was added just because it's the kind of thing trust pages usually say.

## Before this goes live

1. Resolve or explicitly re-confirm the HTTP-transport deferral in `security-audit.md` — this
   page's silence on encryption-in-transit will read as evasive once anyone reads the source
   carefully; better to close the gap than to write around it.
2. Wire this into an actual screen/route once the copy is approved — no Flutter or backend
   work was done this session, this is copy only.
3. Re-check every claim against the app's real behavior at that time — this doc is a snapshot
   of 2026-08-31, not a living source of truth.
