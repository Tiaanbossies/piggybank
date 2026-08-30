# Piggybank Payment Gateway Scope — 2026-08-30

Step 5 of `plans/piggybank-launch-readiness.md`. Hard gate: no gateway-integration code exists
yet, and none is written until this document exists with a concrete decision — this is that
document.

---

## Use case (confirmed with user)

- **Recurring monthly subscription billing only** (Free → Pro tier). No one-off payments
  (advisor fees, in-app purchases) are planned near-term. This rules out pure instant-EFT
  providers that lack native card/token-based recurring billing.
- User's existing business banking relationship is **Capitec**, but this is a plain business
  bank account — **no existing Capitec-linked merchant/gateway partnership or discount**
  (confirmed directly with user; do not assume a special integration path exists).

---

## Providers compared

Ozow and Yoco were screened out before deep research; Paystack and Yoco were still pulled per
user request for the record.

| Provider | Fee structure (verified) | Recurring billing | PCI-DSS scope | Verdict |
| --- | --- | --- | --- | --- |
| **PayFast** | **Verified directly on `payfast.io/fees` (2026-08-30):** Card 3.2% + R2.00/txn; Instant EFT 2.0% (min R2); **Capitec Pay 2.0% (min R2)**; standard payout R8.70/payout (excl. VAT), immediate payout 0.8% (min R14); refund R2.00. No setup/monthly fee. Volume discount available >R50k/month (3-month average). | **Native subscriptions feature**, confirmed on the same pricing page — purpose-built for SaaS/membership billing. | Hosted checkout (redirect) — card data never touches Piggybank's backend, minimal PCI scope. | **Chosen.** |
| **Peach Payments** | Not independently verified on Peach's own pricing page — third-party aggregators cite ~2.95–3.2% + R1.50/txn card, possibly +R300/month account fee, but Peach's own site describes the recurring-billing *feature*, not price. Pricing appears quote/volume-negotiated rather than self-serve. | Native, explicitly marketed for SaaS/subscriptions. | Both hosted checkout and API/SDK integration offered; API path can carry more PCI scope depending on integration choice. | Ruled out — one comparison source flags Peach as better suited to >R500k/month volume; quote-only onboarding is a poor fit for a solo app at launch, vs. PayFast's instant self-service signup. |
| **Paystack** (pulled per user request) | ~2.9% + R1/txn per secondary sources — not independently verified on Paystack's own SA pricing page this session. | Has a subscriptions API, mature in Paystack's NG/GH markets; SA-specific recurring-billing maturity not independently confirmed — SA is a comparatively recent market entry for Paystack. | Hosted "Paystack Popup"/Standard checkout available alongside their API — minimal-scope path exists. | Ruled out for now — viable in principle, but recency of SA launch and unconfirmed subscriptions-API parity in that market make it a weaker bet than PayFast's proven SA-first track record. |
| **Ozow** (screened out, not deep-researched) | SA instant-EFT, typically lower/flat fees. | Instant EFT is bank-to-bank per transaction — no native saved-token recurring billing the way a card does. | N/A | Ruled out — structural mismatch with recurring subscription billing, not a fee-driven decision. |
| **Yoco** (pulled per user request) | N/A — moot given next column. | **Confirmed directly from Yoco's own help centre:** "does not yet support subscriptions or recurring billing, though working on it." | N/A | Ruled out — confirmed unsupported for the actual use case, not a preference call. |

---

## Decision

**Chosen provider: PayFast.**

**Rationale:**
1. Only provider among the four with both (a) a fee structure verified directly on the
   vendor's own current pricing page, and (b) confirmed native recurring/subscription billing
   support on that same page.
2. Self-service onboarding — no sales-quote gate, unlike Peach's apparent volume-negotiated
   pricing. Matches a solo business launching now, not an enterprise with >R500k/month volume.
3. Hosted checkout keeps PCI-DSS scope minimal — card numbers never reach Piggybank's backend.
4. **Capitec Pay is a first-class payment method at the same 2.0% (min R2) rate as Instant
   EFT** — a coincidental fit given the user's own banking relationship. This is a Step 6 UX
   decision (whether to surface Capitec Pay as a distinct option at checkout), not a factor in
   choosing PayFast itself, but worth carrying forward.
5. Proven, SA-first track record (unlike Paystack's more recent SA entry) and no structural
   mismatch with recurring billing (unlike Ozow) or missing feature (unlike Yoco).

**Fee structure to build against:** 3.2% + R2.00 per card transaction (the default recurring
subscription charge method); R8.70 per standard payout to the linked SA bank account. No
monthly/setup fee at current (sub-R50k/month) volume.

**Compliance posture:** PayFast's hosted-checkout / tokenized-recurring flow means Piggybank's
backend never receives, stores, or transmits raw card numbers — this keeps PCI-DSS scope at
SAQ A (the minimal self-assessment tier), not the far heavier SAQ D that a raw-card-handling
integration would require. This should hold as a hard constraint into Step 6: whatever
integration path is chosen (hosted redirect vs. any embedded form) must not introduce raw card
data touching the backend.

**Caveat carried into Step 6:** the numbers above were verified on 2026-08-30 directly on
`payfast.io/fees`; PayFast's own pricing page notes rates are subject to change and a merchant
account signup will show the definitive current contract terms — re-confirm at signup time
rather than trusting this document indefinitely.

---

## What Step 6 inherits from this decision

- Provider: PayFast, subscriptions feature (native recurring), hosted checkout.
- Replace `subscriptions_router.upgrade()`'s pure DB-flag flip with a real charge-then-confirm
  flow: PayFast checkout → webhook (ITN — Instant Transaction Notification, PayFast's webhook
  mechanism) confirms payment → only then flip `tier=PRO`.
- Needs: PayFast merchant account signup (real business details, bank account for payout —
  Capitec account works fine, no special integration needed beyond standard EFT payout details),
  sandbox/test-mode credentials for development, ITN webhook handler + signature verification,
  API keys stored as secrets (not committed — verify against Step 0 security audit's secrets-
  hygiene finding), and a subscription renewal/expiry mechanism that doesn't require the user to
  reopen the app on the exact lapse day.
- Small Flutter change: `subscription_screen.dart`'s Upgrade button needs to launch PayFast's
  hosted checkout (WebView or external browser redirect) instead of the current mocked flip.
