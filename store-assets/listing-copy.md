# Google Play Store Listing Copy

Draft copy for Piggybank's Play Console listing. Paste directly into the relevant
fields — nothing here needs further editing unless the feature set changes.

## App name (30 char max)

```
Piggybank
```
(9 characters)

## Short description (80 char max)

```
Track accounts, budgets, goals & investments — all your wealth in one place.
```
(75 characters)

## Full description (4000 char max)

```
Piggybank gives you one clear view of your entire financial life — built for
South Africans who are done juggling spreadsheets and bank apps that only show
half the picture.

See where you stand
Your net worth, monthly cashflow, and goal progress on one dashboard — no
digging through five different apps to piece it together.

Accounts & transactions
Log transactions manually, import a CSV from your bank, or snap a photo of a
receipt and let Piggybank pull out the details. Filter by account, type,
category, or date range to find exactly what you're looking for.

Budgets that actually warn you
Set monthly budgets per category and see clearly when you're approaching or
over the line — before the month gets away from you.

Goals you can watch grow
Set a savings goal, track progress with every contribution, and see exactly
how close you are — whether it's an emergency fund, a deposit, or something
smaller.

Assets, liabilities & real net worth
Track what you own — property, vehicles, investments, cash — and what you
owe, so your net worth reflects your real financial position, not just your
bank balance.

Investing, the South African way
Track your investment portfolios, including Tax-Free Savings Accounts (TFSA)
and Retirement Annuities (RA), with contribution tracking against the
official annual and lifetime TFSA limits.

Built-in calculators
Work out loan repayments and see how extra payments accelerate paying off
debt, without leaving the app.

AI-powered insights (Pro)
Get a plain-language read on your spending patterns and recurring expenses,
and chat with an AI assistant about your own financial data.

Private and secure
Lock the app behind your fingerprint, face, or a PIN. Your financial data
stays yours — Piggybank is built with South Africa's POPIA privacy
requirements in mind from the ground up.

Free to start, with an optional Pro tier for AI-powered insights and advanced
features.

All your wealth in one place. Download Piggybank and see where you really
stand.
```
(~1,750 characters — well under the 4,000 limit, room to expand later)

## Notes

- Tagline ("All your wealth in one place") is reused verbatim from the app's own
  login screen (`lib/features/auth/screens/login_screen.dart`) and the feature
  graphic, for consistency across every touchpoint.
- Feature list cross-checked against the actual `lib/features/` domains present in
  the app (accounts, transactions, imports, budgets, goals, assets, liabilities,
  portfolios, tfsa, ra, calculators, insights, chatbot, settings) — nothing claimed
  here is aspirational or unbuilt.
- "Pro" gating on AI insights matches the confirmed in-app behavior (Insights tab
  shows "Pro subscription required" on a free-tier account, per this session's own
  screenshot pass).
- Content rating questionnaire and the Data safety section (Play Console UI steps,
  no code artifact) are still a manual step at submission time — same note as the
  plan's Step 9d task list.
