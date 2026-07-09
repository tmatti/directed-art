# Plan 005: Design spike — pre-generated Narration audio (TTS) for every Step

> **Executor instructions**: This is a **design/spike plan**, not a
> build-everything plan. Your deliverable is a written design + a minimal
> proof-of-concept behind a seam, plus a list of open decisions for the
> maintainer — NOT a finished, production-wired TTS feature. Do not integrate a
> paid TTS vendor or commit credentials. When done, update the status row in
> `plans/README.md` and leave your design doc where indicated.
>
> **Drift check (run first)**: `git diff --stat 38eecae..HEAD -- app/jobs/generate_directed_drawing_job.rb app/models/directed_drawing.rb app/models/step.rb app/models/drawing_generator.rb`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: MED
- **Depends on**: plans/003-drawing-schema-narration-validation.md
- **Category**: direction
- **Planned at**: commit `38eecae`, 2026-07-08
- **Issue**: https://github.com/tmatti/directed-art/issues/41

## Why this matters

The core users are children 4–10, many of whom cannot yet read. ADR-0007 makes
this explicit: "a child must be able to *hear* steps … Narration output is a
hard requirement." Today `Step.narration` is stored **text** and the walkthrough
renders it as an italic line with a speaker icon
(`app/javascript/pages/directed_drawings/show.tsx:156-160`) — there is no audio
synthesis and no playback. So the app's central accessibility promise is unmet:
a pre-reader can't actually follow a drawing unassisted. GitHub issue #9 tracks
this. ADR-0007 also fixes the architecture: because the Plan is frozen at
confirmation, each Step's narration text is known up front, so audio is
**pre-generated once at partition time** (not per-page TTS) with a premium
cloud voice, stored via Active Storage (R2), and served statically. This spike
turns that decision into a concrete, seam-based design and a runnable proof of
concept, so a follow-up build plan is low-risk.

## Current state

- `app/models/step.rb` — the Step model; narration is a plain column, no
  attachment:
  ```ruby
  # app/models/step.rb
  class Step < ApplicationRecord
    belongs_to :directed_drawing
    validates :position, presence: true, uniqueness: { scope: :directed_drawing_id }
    validates :instruction, presence: true
  end
  ```
- `app/jobs/generate_directed_drawing_job.rb` — the async pipeline (ADR-0009).
  It validates the drawing, persists it, and marks the plan ready. This is
  where per-Step narration synthesis belongs (at partition time, before
  `ready`):
  ```ruby
  # app/jobs/generate_directed_drawing_job.rb:30-34
  def perform(plan)
    drawing_json = DrawingSchema.validate!(generator.call(plan.attributes_for_generation))
    drawing = DirectedDrawing.create_from_plan!(profile: plan.profile, plan: drawing_json)
    plan.update!(directed_drawing: drawing, status: :ready)
  end
  ```
- `app/models/directed_drawing.rb:74-92` — `as_walkthrough` serializes each
  step (`id, position, instruction, narration, primitives`) for the renderer.
  Audio URL would be added to this payload.
- **Seam pattern to imitate** — the app already isolates every LLM concern
  behind an injectable, fakeable adapter with a `class_attribute` default and a
  test fake:
  - `app/models/drawing_generator.rb` (the real adapter) +
    `GenerateDirectedDrawingJob.generator = ...` (`class_attribute`, default
    real, `generate_directed_drawing_job.rb:17`) +
    `test/support/fake_drawing_generator.rb` (the fake, wired in
    `test/test_helper.rb:45`).
  - `app/models/subject_safety_gate.rb` + `DrawingPlan.subject_safety_gate`
    class_attribute + `test/support/fake_subject_safety_gate.rb`.
  A `NarrationSynthesizer` must follow this exact shape: real RubyLLM/vendor
  adapter, injectable `class_attribute` on the job, and a `FakeNarrationSynthesizer`
  that returns canned audio bytes so tests never hit a vendor.
- ADR-0007 constraints to honor (quote these in the design doc):
  - "synthesize each Step's Narration audio once, at partition time … store the
    resulting audio, and serve it statically."
  - "behind a clean seam so cloud STT can replace it later without touching
    callers" (the seam requirement applies to TTS too — provider-swappable).
  - Voice *input* is a separate, deferred concern (issue #13) — **out of scope
    here**.
- Depends on plan 003: that plan guarantees every persisted Step has a
  non-blank `narration`, so the synthesizer always has text to speak. Confirm
  003 is DONE before wiring synthesis into the job.

## Commands you will need

| Purpose   | Command                                  | Expected on success |
|-----------|------------------------------------------|---------------------|
| Full Ruby tests | `bin/rails test`                   | all pass |
| Job tests | `bin/rails test test/jobs/generate_directed_drawing_job_test.rb` | all pass |
| RuboCop   | `bin/rubocop app/`                       | no offenses |

## Suggested executor toolkit

- Read ADR-0007 (`docs/adr/0007-voice-pregenerated-narration-browser-input.md`)
  and ADR-0009 (`docs/adr/0009-async-generation-pipeline-with-polling.md`) in
  full before designing — they fix the timing (partition-time) and the async
  pipeline this slots into.
- Read GitHub issue #9 (`gh issue view 9`) for the tracked acceptance criteria.

## Scope

This is a spike. Produce:

**In scope (deliverables)**:
1. `plans/005-narration-tts-design.md` (create) — the written design (see
   "Deliverable: design doc" below). This is the primary output.
2. A minimal, **seam-only** proof of concept:
   - `app/models/narration_synthesizer.rb` (create) — the adapter interface
     and a real implementation sketch (may be stubbed/`raise NotImplementedError`
     in the vendor-call body, with the provider seam fully shaped).
   - `test/support/fake_narration_synthesizer.rb` (create) — returns canned
     audio bytes.
   - A migration + `has_one_attached :narration_audio` on `Step` **only if**
     the design settles on per-Step Active Storage attachment (the ADR-0007
     default). Gate this behind the design decision; if you defer it, say so.
3. A short list of open decisions for the maintainer (vendor, voice, cost,
   caching, playback UX) at the end of the design doc.

**Explicitly NOT in scope**:
- Choosing and wiring a real paid TTS vendor / committing any API key.
- Building the frontend audio player UI (design it in prose; do not implement).
- Voice *input* / Web Speech API (issue #13 — different feature).
- Autoplay policy work, offline caching, or multi-language voices.

## Deliverable: design doc (`plans/005-narration-tts-design.md`)

Cover, concretely and grounded in the current code:

1. **Seam** — the `NarrationSynthesizer` interface (`call(text, voice:) ->
   audio bytes + content_type`), its `class_attribute` injection point on
   `GenerateDirectedDrawingJob`, and the `FakeNarrationSynthesizer` test default
   (mirror `generator` / `subject_safety_gate`). Show the exact wiring lines.
2. **Storage** — per-Step Active Storage attachment (`has_one_attached
   :narration_audio`) vs. one combined audio file per drawing. Recommend one,
   with the ADR-0007 "serve it statically" constraint and R2 in mind. Include
   the migration shape if per-Step.
3. **Pipeline placement** — where in `GenerateDirectedDrawingJob#perform`
   synthesis runs (after `create_from_plan!`, before `status: :ready`), how
   partial failure is handled (does one failed step fail the drawing, or degrade
   to text-only?), and how it interacts with the existing retry/`failed!` paths.
   Note the added latency and whether it needs its own job.
4. **Serialization** — the `narration_audio_url` added to
   `DirectedDrawing#as_walkthrough`, and the `Artwork`-style signed-URL approach
   already used (`directed_drawings_controller.rb:40`).
5. **Playback UX (prose only)** — replay button vs. autoplay on page turn, and
   the browser autoplay-policy caveat for a kids' app.
6. **Test strategy** — how the fake keeps the suite vendor-free; what the job
   test asserts (audio attached to each step post-generation).
7. **Cost/latency estimate** and a bulleted **open-decisions** list for the
   maintainer.

## Steps

### Step 1: Confirm the dependency and read the constraints

Confirm plan 003 is DONE (`grep -n "narration is required"
app/models/drawing_schema.rb` returns a match). Read ADR-0007, ADR-0009, and
issue #9.

**Verify**: 003's check present; if not, STOP — synthesis needs guaranteed
narration text.

### Step 2: Write the design doc

Produce `plans/005-narration-tts-design.md` covering the seven sections above.
Ground every claim in the cited files.

**Verify**: the doc exists and each of the seven sections is present and
references real files/lines.

### Step 3: Scaffold the seam (no vendor call)

Create `app/models/narration_synthesizer.rb` (interface + real-adapter sketch;
the vendor HTTP/gem call body may `raise NotImplementedError` with a comment
naming the chosen approach) and `test/support/fake_narration_synthesizer.rb`
(returns canned bytes + content type). Add the injectable `class_attribute` to
the job **without** yet calling it in `perform` (keep the pipeline green).

**Verify**: `bin/rails test` → still all pass (nothing calls the synthesizer
yet); `bin/rubocop app/models/narration_synthesizer.rb` → no offenses.

### Step 4: (Conditional) proof-of-concept wiring behind the fake

Only if the design settles on per-Step attachment AND you can keep the suite
green: add the `has_one_attached :narration_audio` + migration, wire the job to
call the (faked, in tests) synthesizer after `create_from_plan!`, and add a job
test asserting each step gets audio attached. If this expands beyond a tight,
green proof of concept, STOP and leave it for the build plan — document what
remains.

**Verify**: `bin/rails test test/jobs/generate_directed_drawing_job_test.rb` →
all pass; the fake synthesizer is the test default (no vendor call).

## Done criteria

- [ ] `plans/005-narration-tts-design.md` exists with all seven sections, grounded in real files.
- [ ] `app/models/narration_synthesizer.rb` and `test/support/fake_narration_synthesizer.rb` exist and follow the `generator`/`subject_safety_gate` seam pattern.
- [ ] `bin/rails test` exits 0 (suite stays green; no vendor is called in tests).
- [ ] The design doc ends with an explicit open-decisions list for the maintainer.
- [ ] No paid-vendor credential appears anywhere in the diff.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report (do not improvise) if:

- Plan 003 is not DONE (steps may lack guaranteed narration text).
- The proof of concept can't stay green without real vendor calls — leave
  synthesis wiring for the build plan and ship the design + seam only.
- Wiring synthesis appears to require restructuring the async pipeline beyond
  adding a synthesis step (e.g. a second job, schema changes) — document it as
  an open decision instead of building it.

## Maintenance notes

- The follow-up build plan will: pick the vendor, implement the real adapter
  body, decide autoplay/replay UX, and add the frontend player. This spike
  should make that plan mechanical.
- Keep the synthesizer provider-swappable (ADR-0007's "clean seam") — the same
  reason RubyLLM is the single LLM seam.
- A reviewer should check that the seam matches the two existing adapter
  patterns exactly, and that nothing calls a real TTS vendor from the test path.
