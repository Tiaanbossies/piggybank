# Insights UI — design note (blueprint Step 7)

`docs/stitch-design-brief.md` §8 calls Insights "the highest-value new-design
target in the whole brief" and suggests trend charts (net-worth-over-time,
spending-pattern callouts, budget-adherence trends) using the "hero metric
card + progress card + stat strip vocabulary". This note records why the
actual build is narrower than that suggestion, and the concrete decisions
made instead.

## Scope: what the backend actually supports today

`backend/app/insights/router.py` has no trend/time-series endpoint — it has
exactly one AI capability: `POST /insights` takes a free-text `question` and
returns a one-off prose `answer`, computed from a snapshot of the user's
current finance data (`build_user_finance_context`). There is no stored
time-series, no charting data. Building the trend-dashboard version of
Insights the design brief describes would mean inventing new backend
endpoints beyond this blueprint's actual task list ("Question-input
affordance + insight-history list"). This build matches the task list, not
the design brief's more ambitious framing — a trend dashboard is a
legitimate future iteration once/if the backend grows dedicated analytics
endpoints, but it is out of scope here.

## Why not `HeroMetricCard` / `ProgressCard`

Both widgets' own doc comments restrict their use:

- `HeroMetricCard` is "used once per screen ... never repeated as a pattern
  for lesser numbers" — for a single net-worth-style headline number. An AI
  answer is prose, not a number; there is no single metric to headline.
- `ProgressCard` requires a `pct` (0.0–1.0 budget/goal progress value) — not
  applicable to free-text Q&A at all.

Using either here would mean bending a component past what its own
established convention says it's for, which is exactly the kind of
"forcing a fourth visual language via a component that doesn't fit" the
brief's Anti-Patterns section warns against elsewhere. Instead:

- The just-asked answer renders in a plain `Card` with the answer as prose,
  plus a small `Wrap` of muted stat text (days covered, counts of
  transactions/budgets/assets/etc.) directly below it — the same "stat
  strip" idea as the Dashboard's `_CashflowStatStrip` (a `Card` with a row of
  labeled numbers), not a new component.
- The history list below it reuses `GroupCard`/`GroupRow`, the same
  established pattern as `ImportHistoryScreen`.

## Why the just-asked answer's stat strip disappears after refresh

`InsightOut` (what `GET /insights/` returns for history) does not persist
`data_scope` — only `InsightResponse` (the direct answer to `POST /insights`)
includes it. So the richer "asked over N days, M transactions considered"
detail is only ever shown for the answer just given, in
`InsightsAskController.state.lastResult`; once the history list is
refreshed, that same entry appears as a plain title/subtitle row like every
other past insight. This is a backend data-shape constraint, not a UI
oversight — documented here so a future session doesn't "fix" it by trying
to smuggle `data_scope` onto the history list without a backend change.

## Paywall and rate-limit handling

Same convention as `ChatbotScreen`: no proactive `/insights/health` check
before showing the question box. Hitting Ask is the moment eligibility is
tested. A 402 pops the screen and shows the generic `showPaywallPrompt`
dialog. The backend's 60-second-per-question rate limit (429) is treated as
a plain inline error message under the question box — no countdown timer or
disabled-until-cooldown UI, since the task list did not call for one and the
error message itself already tells the user how long to wait.
