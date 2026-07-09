# Plan 003: DrawingSchema requires a non-blank narration on every step

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 38eecae..HEAD -- app/models/drawing_schema.rb test/models/drawing_schema_test.rb app/models/directed_drawing.rb`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `38eecae`, 2026-07-08
- **Issue**: https://github.com/tmatti/directed-art/issues/39

## Why this matters

`narration` is the spoken instruction a pre-reader hears — ADR-0007 calls it "a
first-class output of every Step … a hard requirement," and the generator's own
request schema marks `narration` **required**
(`drawing_generator.rb:78`). But the app's authoritative validator,
`DrawingSchema`, only checks `instruction` and `primitives` — it never checks
`narration`. So a model that returns a step with a missing or blank narration
passes validation and persists with `narration = NULL`. The walkthrough then
renders nothing where the spoken line should be, and the upcoming narration-TTS
work (plan 005) has no text to synthesize. Since `DrawingSchema` is the single
authority that "a provider or model swap can never silently produce a broken
drawing" (ADR-0006), the guarantee should cover narration too. After this plan,
a step without a real narration is rejected and retried like any other
malformed output.

## Current state

- `app/models/drawing_schema.rb` — `step_errors` validates `instruction` and
  `primitives`, but not `narration`:
  ```ruby
  # app/models/drawing_schema.rb:72-87
  def step_errors(step, width, height, label)
    return [ "#{label} must be an object" ] unless step.is_a?(Hash)

    errors = []
    errors << "#{label} instruction is required" if blank?(step["instruction"])

    primitives = step["primitives"]
    unless primitives.is_a?(Array) && primitives.any?
      return errors << "#{label} must have at least one primitive"
    end

    primitives.each_with_index do |primitive, j|
      errors.concat(primitive_errors(primitive, width, height, "#{label} primitive #{j + 1}"))
    end
    errors
  end
  ```
  `blank?` is already defined (`drawing_schema.rb:132-134`):
  `value.to_s.strip.empty?`.
- `app/models/drawing_generator.rb:78` — the generation request schema:
  `required: %w[instruction narration primitives]` (narration is required
  there, confirming the intent).
- Validation failures raise `DrawingSchema::InvalidDrawing`, which the job
  retries (`generate_directed_drawing_job.rb:23`) — so rejecting a
  narration-less step just triggers the existing retry, no new machinery.

Repo conventions to follow:
- Match the exact error-string style already used: `"#{label} instruction is
  required"`. Use `"#{label} narration is required"`.
- Tests live in `test/models/drawing_schema_test.rb`, `ActiveSupport::TestCase`,
  with a `valid_drawing` helper mutated per case. Every step in `valid_drawing`
  already has a `narration` (lines 21, 25), so the happy path stays green.

## Commands you will need

| Purpose   | Command                                              | Expected on success |
|-----------|------------------------------------------------------|---------------------|
| Tests (schema) | `bin/rails test test/models/drawing_schema_test.rb` | all pass |
| Full Ruby tests | `bin/rails test`                                  | all pass |
| RuboCop   | `bin/rubocop app/models/drawing_schema.rb`           | no offenses |

## Scope

**In scope**:
- `app/models/drawing_schema.rb`
- `test/models/drawing_schema_test.rb` (extend)

**Out of scope** (do NOT touch):
- `app/models/drawing_generator.rb` — its request schema already requires
  narration.
- `app/models/step.rb` — do not add an ActiveRecord `validates :narration`
  here; the DSL validator is the single authority per ADR-0006, and a model-
  level validation would double-guard inconsistently and could break the
  candidate-discard path. Keep the check in `DrawingSchema` only.
- The frontend `narration` rendering.

## Git workflow

- Branch: `advisor/003-drawing-schema-narration-validation`
- Commit style matches `git log` (e.g. "Require narration on every drawing step").
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add the narration check

In `app/models/drawing_schema.rb`, add one line to `step_errors`, right after
the instruction check:

```ruby
errors << "#{label} instruction is required" if blank?(step["instruction"])
errors << "#{label} narration is required" if blank?(step["narration"])
```

**Verify**: `bin/rails runner 'd = {"subject"=>"x","title"=>"t","canvas"=>{"width"=>600,"height"=>600},"steps"=>[{"instruction"=>"i","primitives"=>[{"type"=>"circle","cx"=>10,"cy"=>10,"r"=>5}]}]}; puts DrawingSchema.validate(d).inspect'`
→ output includes `"step 1 narration is required"`.

### Step 2: Add test cases

In `test/models/drawing_schema_test.rb`, under the per-step validation section,
add tests mirroring the existing instruction tests:
- a step with a missing `narration` key is rejected,
- a step with a blank/whitespace `narration` is rejected,
- confirm the error message reads like the others (`… narration is required`).

Follow the existing pattern of copying `valid_drawing` and deleting/blanking
the field, e.g. `d = valid_drawing; d["steps"][0].delete("narration")`.

**Verify**: `bin/rails test test/models/drawing_schema_test.rb` → all pass, including the new cases, and the existing "well-formed drawing … passes" test stays green.

## Test plan

- New cases in `drawing_schema_test.rb`: missing narration rejected; blank
  narration rejected; message text asserted.
- Existing happy-path and instruction/primitive tests unchanged and green.
- Verification: `bin/rails test test/models/drawing_schema_test.rb` → all pass.

## Done criteria

ALL must hold:

- [ ] `bin/rails test` exits 0; new narration tests exist and pass.
- [ ] `grep -n "narration is required" app/models/drawing_schema.rb` → one match.
- [ ] `bin/rubocop app/models/drawing_schema.rb` → no offenses.
- [ ] The `valid_drawing` happy-path test still passes (no false rejection).
- [ ] No files outside the in-scope list are modified (`git status`).
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report if:

- Any existing test that was green now fails because a fixture step lacks
  narration — that means production fixtures/fakes ship narration-less steps;
  report which, do not delete the new check.
- The "Current state" excerpts don't match the live code.
- `bin/rails test` cannot reach PostgreSQL.

## Maintenance notes

- Plan 005 (narration TTS) depends on this: it assumes every persisted step has
  a non-blank narration to synthesize. Land this first.
- A reviewer should confirm the check uses the shared `blank?` helper (so
  whitespace-only narration is rejected too), consistent with `instruction`.
