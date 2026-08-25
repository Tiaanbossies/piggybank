# Admin Panel — Scope (Step 0 outcome, Production Completion blueprint)

**Status:** Scoping conversation complete (2026-08-23). This document is Step 0's
required deliverable per `plans/piggybank-production-completion.md` — until this
existed, no Admin implementation work was permitted. Implementation itself is a
**separate follow-up blueprint**, not scoped here.

## Who "admin" is

Just the sole developer, for now — not a support team or customer-facing role. No
multi-tier admin hierarchy needed.

## Existing infrastructure to reuse (do not reinvent)

`finance-app.v3-main/backend/app/admin/router.py` already has the role-gating pattern
proven and working: a `UserRole` enum (`ADMIN`/`USER`) on `User.role`
(`backend/app/models.py:115`), and a `_require_admin` FastAPI dependency wrapping
`get_current_user`. The one existing endpoint, `POST /admin/refresh-prices`
(rate-limited 5/minute, runs as a background task), is the template every new admin
endpoint below should follow — same router, same `_require_admin` dependency, same
`admin_router` object.

`User` already has `is_active: bool` (`models.py:116`) — enable/disable is a field
that exists today, no migration needed for that specific action. There is **no**
`last_login`/`last_seen` timestamp anywhere on `User` — any "active users" metric
needs either a new column (small migration) or an approximation from existing
activity tables (e.g. most-recent `Transaction.created_at` per user) — flagged as an
open implementation decision, not resolved here.

## Confirmed feature set

1. **Trigger price refresh** — already fully built server-side
   (`POST /admin/refresh-prices`). Zero backend work. Client work only: a button in
   the admin UI.
2. **User account lookup/management** — new backend endpoints needed:
   - `GET /admin/users?search=&page=&limit=` — paginated search/list (by email/name).
   - `GET /admin/users/{user_id}` — detail view (profile, subscription tier, account/
     transaction counts, `created_at`).
   - `PATCH /admin/users/{user_id}` — **limited, safe fields only** — toggling
     `is_active` (existing field) to disable/enable login. **Explicitly excludes
     hard-delete** — `docs/delete-policy.md` in `finance-app.v3-main` already
     documents user deletion as "never soft-deleted, hard delete cascades, ops-only,"
     meaning that's a deliberate manual ops action outside the app, not something to
     wire into a casual admin UI button. Keep it that way.
3. **Subscription overrides** — new endpoint: `POST /admin/users/{user_id}/
   subscription/override` — body: target tier + optional expiry. Should be
   audit-logged (who did it, when, and ideally why — a required free-text reason
   field is worth the small extra friction, since this bypasses normal payment flow).
4. **Usage metrics dashboard** — new endpoint: `GET /admin/metrics` — aggregate
   counts only (total users, new users in the last 7/30 days, total accounts/
   transactions platform-wide). **This is explicitly not true error-rate/APM
   telemetry** — no error-tracking/monitoring infrastructure (e.g. Sentry) exists
   anywhere in this codebase today, and standing one up is a separate, much larger
   initiative outside this admin panel's scope. If real error-rate visibility is
   wanted later, that's its own project, not folded into "usage/error metrics" here.

## Flutter client scope (future implementation, not built by this document)

- New feature directory: `lib/features/admin/`, reachable only when the logged-in
  user's `role == UserRole.ADMIN` (already available from the `/auth/me` response
  fetched at login — no new client-side auth plumbing needed to gate visibility).
- Entry point: a Settings row, conditionally rendered only for admin-role accounts.
- Screens: an Admin dashboard (metrics + the price-refresh trigger button), a
  User list/search screen, a User detail screen (with the subscription-override
  action).

## Explicitly out of scope for this v1 Admin spec

- True error-rate/APM metrics (separate future initiative).
- Multi-admin role hierarchy (super-admin vs. support-admin) — not needed for a
  single-developer use case.
- User hard-delete via the admin UI — stays a manual, deliberate ops action per the
  existing delete-policy doc.
- Content/data moderation — not selected in this scoping conversation.

## Next step

This spec satisfies Step 0's exit criteria. Building it is a new, separate blueprint
(new backend endpoints + a small migration if an "active users" timestamp is added +
new Flutter screens) — run the blueprint skill again against this spec when ready to
implement, rather than treating this document itself as an implementation plan.
