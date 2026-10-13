# Research: tracking retirement annuity funds (unit trusts)

QA pass 1 (2026-10-12) item G: "We need to investigate a way to track retirement annuity funds such as
Sygnia Skeleton Balanced 70 Fund." This is research only; no code changed. Tiaan chose this scope.

## 1. Why it doesn't work today

An RA is usually held in **unit trusts** (collective investment schemes), not JSE-listed shares. Piggybank's
price chain is built for listed instruments:

- `backend/app/market_data/chain.py` tries crypto through CoinGecko → yfinance, and equities through Twelve Data → FMP →
  Alpha Vantage → Finnhub → Marketstack → yfinance. **No source supplies fund NAVs.**
- `portfolios/price_service.py` resolves a ticker as `{ticker}.JO` first. A made-up code like `SYG`
  becomes **`SYG.JO`, which is Sygnia Ltd's own share**. That price would overwrite the fund's.
- Holdings already allow a manual `current_price` (`portfolios/schemas.py`; the "Current price (optional)"
  field). If the ticker never resolves, the nightly refresh leaves it alone but logs an error every run.

## 2. Price sources for SA unit trusts

| Source | What it gives | Access / cost | Frequency | Fit |
|---|---|---|---|---|
| **FundsData (ProfileData)** | The reference SA unit trust database: daily NAV, TER, fund size, fact sheets. Example: Sygnia Skeleton Balanced 70 class A is code `SSBCA` (NAV about R2.24 on 22 Jan 2026, TER 0.45%, about R11 bn). | Free fact-sheet *pages* for investors. **Data feed (API/CSV/XML/SQL) is a commercial licence** priced by user group, modules and delivery; contact ProfileData. | Daily, after market close | **Best data, but paid and licensed.** Scraping the free pages would break their terms. |
| **Manager's own site (sygnia.co.za)** | Fact sheets (monthly PDF) and fund pages with recent prices | Free to read; no API; layout varies by manager | Monthly PDFs; some pages daily | One scraper per manager. Brittle, and Piggybank users hold many managers. |
| **Yahoo Finance (Morningstar `0P…` IDs)** | Some SA unit trusts appear as `0P0000XXXX.F`-style MUTUALFUND quotes | Free via yfinance (already a dependency); unofficial | Patchy, often stale | **Not found for Skeleton Balanced 70.** Not worth relying on. |
| **EODHD** | End-of-day prices for many exchanges | Paid plans | Daily | **No evidence of SA unit trust NAV coverage.** Check with their support before counting on it. |
| **Platforms (EasyEquities, 10X, Allan Gray, Sygnia's own)** | The user's real units and value | No public API | Live in the platform | Matches what the user actually holds, but there's no API. A statement import or OCR could use these values (see §4). |

## 3. Gaps in the current RA feature (found during exploration)

1. **The RA limit is wrong.** `backend/app/ra/router.py:21` hardcodes **R36,000**, which is the *TFSA* annual cap. The
   RA deduction (section 11F) is **27.5% of the greater of remuneration or taxable income**, capped at
   **R350,000 for the 2026 tax year** and **R430,000 from 1 March 2026** (Budget 2026). Excess contributions
   carry forward to the next year. The limit needs the user's income, which the savings plan already estimates
   (`savings/service.py`) or which the user could enter.
2. **Contributions aren't linked to holdings.** `RaContribution` stands alone: tax year, amount, date, notes and
   provider. It has no portfolio or holding.
3. **The projection ignores market value.** `growth_projection.dart` compounds total contributions at a fixed rate.
   It ignores the fund's actual value and future contributions.
4. **No asset class for a fund.** MUTUALFUND maps to ETF in `asset_class_style.dart`.
5. **The ticker search crashes on null.** `TickerSearchResult.fromJson` casts `instrument_type` as a non-null String. The
   backend can return null, so one such result breaks the whole autocomplete.
6. **The SYG → `SYG.JO` collision** (§1).

## 4. Recommended approach

**Phase 1: manual-priced funds (no new data source, about one PR).**
- Add a **"Unit trust / fund" holding type** with `price_source = manual`. The nightly refresh skips it, which removes
  the ticker collision and the error spam. The user enters units and the unit price from their statement or fact
  sheet, or simply the current value.
- In the RA portfolio, show **market value = sum of holdings**, and link contributions to the RA portfolio.
- Fix the RA limit: 27.5% of income, capped at R350k/R430k by tax year, with a carry-forward note.
- Project from current value plus planned monthly contributions.
- Prompt to update the price monthly, via the notifications inbox (PR 7).
- Fix gap 5 while there.

**Phase 2: automatic NAVs (decide after Phase 1 is in use).**
- Get a quote from **ProfileData for a FundsData NAV feed**: a small closed-user-group licence covering daily NAVs
  only. It's the only source that covers every SA unit trust reliably. Map holdings to FundsData codes (e.g.
  `SSBCA`) and refresh nightly into `price_cache`.
- Don't scrape FundsData's free pages or managers' sites in production: it breaks their terms and is brittle.

**Phase 3, optional: statement import.** Read the platform's monthly statement (PDF/CSV) with the existing
import/OCR path to update units and value, as receipt scanning already does.

## 5. Questions for Tiaan

1. Is Phase 1 (manual price) enough for the beta?
2. Should I ask ProfileData for a FundsData NAV quote?
3. Should the RA limit fix (gap 1) and the null crash (gap 5) go in now as small separate fixes? They're bugs,
   not research.

## Sources

- [FundsData: Sygnia Skeleton Balanced 70 (SSBCA)](https://fundsdata.co.za/Summary.aspx?c=SSBCA)
- [ProfileData: FundsData products and delivery](https://profile.co.za/unit-trusts-data/fundsdata.html)
- [ProfileData: FundsData Online](https://profile.co.za/unit-trusts-data/fundsdata-online.html)
- [Sygnia Skeleton Balanced 70 fact sheet](https://www.sygnia.co.za/wp-content/uploads/2025/03/Sygnia-Skeleton-Balanced-70-Fund.pdf)
- [EasyEquities: Skeleton Balanced 70 unit trust](https://wealth.easyequities.co.za/unittrust/zae000181087)
- [Budget 2026 Tax Guide (R430,000 cap)](https://www.treasury.gov.za/documents/national%20budget/2026/sars/Budget%202026%20Tax%20guide.pdf)
- [Budget 2025 Tax Guide (R350,000 cap)](https://www.treasury.gov.za/documents/National%20Budget/2025Mar/sars/Budget%202025%20Tax%20Guide.pdf)
- [Moonstone: threshold change in effect](https://www.moonstone.co.za/budgets-retirement-threshold-changes-in-effect-despite-legislative-omission/)
