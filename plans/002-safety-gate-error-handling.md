# Plan 002: A safety-gate LLM error denies (never 500s the child), and unparseable denials are logged

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 38eecae..HEAD -- app/models/subject_safety_gate.rb app/models/drawing_plan.rb test/models/subject_safety_gate_test.rb`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `38eecae`, 2026-07-08
- **Issue**: https://github.com/tmatti/directed-art/issues/38

## Why this matters

`SubjectSafetyGate` documents the "over-block" contract (ADR-0003): "a deny, an
unparseable response, an error is a deny." The parsing side honors it, but if
the RubyLLM call itself **raises** (provider down, rate-limit, timeout, network
error), the exception propagates uncaught through `DrawingPlan#gate_subject`
into `DrawingPlansController#update`, so the child's planning chat returns a
raw 500 the moment they type a free-text Subject during any provider hiccup.
The documented behavior is: an error is a deny (gentle redirect to the safe
chips), not a crash. Separately, when the gate denies on an unparseable
response there is no log line, so an operator can't tell "provider degraded and
we're denying everything" from normal denials. After this plan, a gate error
denies safely and every non-explicit-allow is observable.

## Current state

- `app/models/subject_safety_gate.rb` — the gate. `call` invokes the model and
  parses defensively, but does not rescue the model call, and `parse_verdict`
  denies silently:
  ```ruby
  # app/models/subject_safety_gate.rb:75-88
  def call(subject)
    chat = @chat_builder.call(model: @model, provider: @provider)
    response = chat.with_instructions(PROMPT).with_schema(SCHEMA).ask(subject)
    parse_verdict(response.content)
  end

  private

  def parse_verdict(content)
    content.is_a?(Hash) && content["allow"] == true ? Verdict.allow : Verdict.deny
  end
  ```
  The over-block contract is spelled out in the class comment
  (`subject_safety_gate.rb:8-15`): "everything else (a deny, an unparseable
  response, an error) is a deny — the over-block default."
- `app/models/drawing_plan.rb` — the caller; treats a deny as a gentle
  redirect (records a rejection, leaves Subject blank), never an error:
  ```ruby
  # app/models/drawing_plan.rb:184-190
  def gate_subject(slot, typed)
    verdict = subject_safety_gate.call(typed)
    return fill(slot, typed) if verdict.allowed?

    subject_rejections.create!(subject: typed, profile: profile)
    true
  end
  ```

Repo conventions to follow:
- `Rails.logger` is the logging seam (see `config/initializers/ruby_llm.rb`
  which sets `config.logger = Rails.logger`). Use `Rails.logger.warn` for the
  degraded-but-safe case; do **not** log the Subject text verbatim (child PII —
  ADR-0003 keeps rejected text out of general logs; log a length/label only).
- The gate is unit-tested in `test/models/subject_safety_gate_test.rb` with a
  `RecordingChat` stand-in injected via the `chat_builder` seam. Add a chat
  stand-in that **raises** to test the error path — follow the existing
  `gate_with_recording_chat` helper pattern.
- `Verdict.deny` is the over-block value; return it, never re-raise.

## Commands you will need

| Purpose   | Command                                                   | Expected on success |
|-----------|-----------------------------------------------------------|---------------------|
| Tests (gate) | `bin/rails test test/models/subject_safety_gate_test.rb` | all pass |
| Tests (flow) | `bin/rails test test/integration/drawing_plans_test.rb`  | all pass |
| Full Ruby tests | `bin/rails test`                                       | all pass |
| RuboCop   | `bin/rubocop app/models/subject_safety_gate.rb`           | no offenses |

## Scope

**In scope**:
- `app/models/subject_safety_gate.rb`
- `test/models/subject_safety_gate_test.rb` (extend)

**Out of scope** (do NOT touch):
- `app/models/drawing_plan.rb` — the caller already treats any deny as a gentle
  redirect; once the gate returns `Verdict.deny` on error instead of raising,
  the caller needs no change. Changing it risks the documented redirect flow.
- `app/prompts/subject_safety.md` — the prompt is fine.
- The `DirectedArt::LLM` config.

## Git workflow

- Branch: `advisor/002-safety-gate-error-handling`
- Commit style matches `git log` (e.g. "Deny and log on safety-gate LLM error").
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Rescue the model call and deny; log the degraded path

In `app/models/subject_safety_gate.rb`, wrap the model interaction so any
`StandardError` from the chat becomes an over-block deny with a warning log.
Also add a warning when `parse_verdict` denies on a non-explicit-allow so a
degraded provider is visible. Target shape:

```ruby
def call(subject)
  chat = @chat_builder.call(model: @model, provider: @provider)
  response = chat.with_instructions(PROMPT).with_schema(SCHEMA).ask(subject)
  parse_verdict(response.content)
rescue StandardError => e
  Rails.logger.warn("[SubjectSafetyGate] over-blocking after gate error: #{e.class}")
  Verdict.deny
end

private

def parse_verdict(content)
  return Verdict.allow if content.is_a?(Hash) && content["allow"] == true

  Rails.logger.warn("[SubjectSafetyGate] over-blocking unparseable verdict (#{content.class})")
  Verdict.deny
end
```

Do NOT include the Subject text or the exception message body in the log (they
can carry the child's raw input) — the class name is enough to correlate an
outage. Keep the over-block guarantee: every non-`true` path returns
`Verdict.deny`.

**Verify**: covered by Step 2 tests.

### Step 2: Test the error path and the log

In `test/models/subject_safety_gate_test.rb`, add:
- A test that a chat whose `ask` (or `with_instructions`) raises
  `StandardError` yields a **denied** verdict (not a raised error). Add a small
  `RaisingChat` stand-in mirroring `RecordingChat`, or extend the
  `chat_builder` lambda to return an object that raises. Assert
  `gate.call(@subject).denied?` and `assert_nothing_raised`.
- Optionally assert `Rails.logger` receives a warn on that path (use
  `assert_logged`-style or stub `Rails.logger`); if the suite has no logging
  assertion helper, a plain behavioral assertion (denied, not raised) is
  sufficient — do not invent a logging framework.

The existing "over-blocks when the model response is missing or unparseable"
test (`subject_safety_gate_test.rb:93-100`) must still pass — `parse_verdict`
still returns deny for `nil`, `{}`, `{"allow"=>nil}`, etc.

**Verify**: `bin/rails test test/models/subject_safety_gate_test.rb` → all pass, including the new error-path test.

### Step 3: Confirm the flow doesn't error end-to-end

Run the planning-chat integration suite to confirm nothing downstream expected
an exception.

**Verify**: `bin/rails test test/integration/drawing_plans_test.rb` → all pass.

## Test plan

- New unit test: a raising chat → `Verdict.deny`, no exception escapes.
- Existing unparseable-verdict test stays green (regression guard on the
  over-block default).
- Existing integration deny-flow test
  (`drawing_plans_test.rb` "an off-limits free-text Subject is gently
  redirected…") stays green.
- Verification: `bin/rails test test/models/subject_safety_gate_test.rb test/integration/drawing_plans_test.rb` → all pass.

## Done criteria

ALL must hold:

- [ ] `bin/rails test` exits 0; a test proves a gate LLM error yields a denied verdict without raising.
- [ ] `bin/rubocop app/models/subject_safety_gate.rb` → no offenses.
- [ ] `grep -n "rescue" app/models/subject_safety_gate.rb` shows the rescue in `call`.
- [ ] No Subject text or exception message body is written to logs (`grep -n "subject" app/models/subject_safety_gate.rb` in the logging lines shows none).
- [ ] No files outside the in-scope list are modified (`git status`).
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report if:

- Making the error path safe appears to require editing `drawing_plan.rb`
  (it should not).
- The "Current state" excerpts don't match the live code.
- `bin/rails test` cannot reach PostgreSQL.

## Maintenance notes

- If retry/backoff or a circuit breaker is later added for the gate, it belongs
  in this `rescue` boundary — keep the deny-on-final-failure guarantee.
- A reviewer should confirm the over-block invariant is intact: there is no code
  path where a gate error or malformed response yields `Verdict.allow`.
- Deferred (do not do here): surfacing a distinct "we're having trouble, try a
  chip" message to the child. Today an error looks like a normal redirect, which
  is acceptable per ADR-0003's over-block bias.
