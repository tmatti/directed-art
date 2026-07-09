# Plan 004: The LLM-backed plan and generation endpoints are rate-limited per account

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 38eecae..HEAD -- app/controllers/drawing_plans_controller.rb app/controllers/drawing_plans/generations_controller.rb app/controllers/application_controller.rb`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `38eecae`, 2026-07-08
- **Issue**: https://github.com/tmatti/directed-art/issues/40

## Why this matters

Every drawing generation is a paid LLM call (OpenRouter → Claude) plus a
background-queue slot; every plan create is a DB write and the entry point to
generation. Neither endpoint is throttled. A compromised or scripted account
can enqueue generations in a tight loop, running up LLM spend and starving the
Solid Queue for everyone else. Rails 8.1 ships a built-in controller
`rate_limit` (backed by Solid Cache, already in this app) — this is a
few-lines-per-controller change, not new infrastructure. After this plan, a
single session can't submit generations or spin up plans faster than a sane
ceiling, and excess requests get a friendly redirect instead of doing work.

## Current state

- `app/controllers/drawing_plans/generations_controller.rb` — `create`
  enqueues the paid job; no throttle:
  ```ruby
  # app/controllers/drawing_plans/generations_controller.rb:14-24
  def create
    plan.submit_for_generation
    if plan.generating?
      redirect_to drawing_plan_generation_path(plan)
    elsif plan.ready?
      redirect_to directed_drawing_path(plan.directed_drawing)
    else
      redirect_to drawing_plan_path(plan)
    end
  end
  ```
- `app/controllers/drawing_plans_controller.rb` — `create` opens a new plan; no
  throttle:
  ```ruby
  # app/controllers/drawing_plans_controller.rb:10-13
  def create
    plan = Current.active_profile.drawing_plans.create!(age_band: Current.active_profile.age_band)
    redirect_to drawing_plan_path(plan)
  end
  ```
- Both controllers subclass `InertiaController` (→ `ApplicationController`) and
  `include RequiresActiveProfile`, so `Current.session` / `Current.user` /
  `Current.active_profile` are available for keying the limit.
- Solid Cache is configured (`gem "solid_cache"` in `Gemfile`; it backs
  `Rails.cache`), which is what `rate_limit` uses by default.

Repo conventions to follow:
- Rails 8 `rate_limit` is a class-level macro in a controller:
  `rate_limit to: N, within: T, by: -> { ... }, with: -> { ... }`. Key by the
  authenticated identity, not IP (a family shares an IP). Use the current
  session/user id.
- Controllers here redirect rather than render raw errors (see the planning
  chat's friendly-redirect style). The `with:` handler should redirect with a
  gentle flash, not raise a bare 429 page, since a child could conceivably trip
  a generous limit by tapping fast.
- Tests are request/integration tests under `test/integration/`. There is an
  existing `test/integration/drawing_plans/generations_test.rb` to extend.

## Commands you will need

| Purpose   | Command                                                          | Expected on success |
|-----------|------------------------------------------------------------------|---------------------|
| Tests (generation) | `bin/rails test test/integration/drawing_plans/generations_test.rb` | all pass |
| Tests (plans) | `bin/rails test test/integration/drawing_plans_test.rb`       | all pass |
| Full Ruby tests | `bin/rails test`                                             | all pass |
| RuboCop   | `bin/rubocop app/controllers/drawing_plans/generations_controller.rb app/controllers/drawing_plans_controller.rb` | no offenses |

## Scope

**In scope**:
- `app/controllers/drawing_plans/generations_controller.rb`
- `app/controllers/drawing_plans_controller.rb`
- `test/integration/drawing_plans/generations_test.rb` (extend)
- `test/integration/drawing_plans_test.rb` (extend, if a plan-create limit test fits)

**Out of scope** (do NOT touch):
- `app/controllers/application_controller.rb` — do not add a global throttle;
  keep the limits on the two paid/expensive endpoints only, so login, polling
  (`generations#show`), and navigation are never throttled.
- `generations#show` (the poll endpoint) — it must stay unthrottled; the wait
  screen polls it every 1.5s by design (ADR-0009). Only throttle `create`.
- Solid Cache / queue configuration.

## Git workflow

- Branch: `advisor/004-rate-limit-llm-endpoints`
- Commit style matches `git log` (e.g. "Rate-limit plan and generation creation").
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Throttle generation submission

In `app/controllers/drawing_plans/generations_controller.rb`, add a class-level
limit scoped to `create` only. Target shape:

```ruby
class GenerationsController < InertiaController
  include RequiresActiveProfile

  rate_limit to: 10, within: 1.minute, only: :create,
    by: -> { Current.session&.id },
    with: -> { redirect_to drawing_plan_path(params[:drawing_plan_id]), alert: "Let's slow down a moment and try that again." }

  def create
    # ...unchanged...
```

Pick a ceiling generous enough that a normal child tapping "Try again" a few
times never trips it (10/min is a starting point) but that stops a scripted
loop. If `Current.session&.id` is not a valid `by:` key at load time, key by
`-> { Current.user&.id }` instead.

**Verify**: covered by Step 3 tests.

### Step 2: Throttle plan creation

In `app/controllers/drawing_plans_controller.rb`, add a similar but looser
limit on `create` only (plan creation is cheaper than generation but is the
funnel into it), e.g. `to: 20, within: 1.minute`, keyed the same way, redirect
`with:` to the active-profile entry or the profile's plans list. Do not
throttle `show`/`update` (a child answers many chat turns per plan).

**Verify**: covered by Step 3 tests.

### Step 3: Test the throttle

In `test/integration/drawing_plans/generations_test.rb`, add a test that issues
more than the configured number of `create` requests in the window and asserts
the surplus request is redirected by the limiter (e.g. `assert_response
:redirect` / the alert flash) and did **not** enqueue another
`GenerateDirectedDrawingJob` (assert on `enqueued_jobs` count or
`assert_no_enqueued_jobs` for the over-limit call).

Rails' rate limiter uses `Rails.cache`; the test environment must use a cache
store that actually counts (memory store is fine). If the test env cache is
`:null_store`, the limiter no-ops and the test can't pass — in that case STOP
and report rather than reconfiguring global test settings.

Model the test structurally on the existing tests in that file (same
`sign_in` / active-profile setup).

**Verify**: `bin/rails test test/integration/drawing_plans/generations_test.rb` → all pass, including the new over-limit test.

## Test plan

- New test: N+1 rapid `generations#create` calls → the last is limited
  (redirect + flash) and enqueues no job.
- Existing generation tests (submit → generating → poll) stay green; the poll
  endpoint is never throttled.
- Optional: a plan-create over-limit test in `drawing_plans_test.rb`.
- Verification: `bin/rails test test/integration/drawing_plans/generations_test.rb test/integration/drawing_plans_test.rb` → all pass.

## Done criteria

ALL must hold:

- [ ] `bin/rails test` exits 0; an over-limit test proves surplus generation `create`s are throttled and enqueue no job.
- [ ] `grep -rn "rate_limit" app/controllers` → matches in both target controllers, and none in `application_controller.rb`.
- [ ] `generations#show` (poll) is not throttled (`only: :create` present).
- [ ] `bin/rubocop` on both controllers → no offenses.
- [ ] No files outside the in-scope list are modified (`git status`).
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report if:

- The test-env cache store is `:null_store` (rate limiter no-ops) — reconfiguring
  it is out of scope; report so the operator can decide.
- `rate_limit` is unavailable in this Rails version (`grep -rn "def rate_limit"
  $(bundle show actionpack)/lib` finds nothing) — do not hand-roll a limiter;
  report.
- The "Current state" excerpts don't match the live code.
- `bin/rails test` cannot reach PostgreSQL.

## Maintenance notes

- Tune `to:`/`within:` from real usage; the initial numbers are conservative
  guesses. If legitimate rapid retries trip the limit, raise the generation
  ceiling rather than removing it.
- If a plan/generation API is ever exposed to non-browser clients, revisit the
  `by:` key (session id assumes a cookie session).
- A reviewer should confirm the poll endpoint and auth flows remain unthrottled.
