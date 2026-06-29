# frozen_string_literal: true

# The output of the guided planning chat: the Plan attributes that describe the
# finished picture (subject, action, mood, background). Assembled one question
# at a time — a slot-filling conversation — for the active Profile. No drawing
# is generated yet; this records the child's intent only.
class DrawingPlan < ApplicationRecord
  belongs_to :profile
  # The Directed Drawing this Plan's generation produced, set by the job on
  # success (ADR-0009). Null until then.
  belongs_to :directed_drawing, optional: true
  # Subjects the safety gate refused while this Plan was being built (ADR-0003),
  # logged to tune the classifier from real data.
  has_many :subject_rejections, dependent: :destroy

  # The Subject safety gate (ADR-0003): the cheap-LLM classifier that free-text
  # and transcribed-voice Subjects pass through before acceptance. Curated
  # suggestion chips are safe by construction and bypass it. Defaults to the
  # real RubyLLM-backed `SubjectSafetyGate`; the test suite swaps in the fake via
  # `test_helper`, and individual tests may inject their own stub and restore it
  # in teardown (same convention as `GenerateDirectedDrawingJob.generator`).
  class_attribute :subject_safety_gate, default: SubjectSafetyGate.new

  enum :age_band, Profile::AGE_BANDS, validate: true
  # The Plan's linear lifecycle: assembled through the chat (building →
  # completed), then submitted for generation (generating → ready, or failed
  # when the generator can't produce a schema-valid drawing). The wait screen
  # polls this from generating until ready (ADR-0009).
  enum :status,
    { building: 0, completed: 1, generating: 2, ready: 3, failed: 4 },
    default: :building, validate: true

  # One question per Plan attribute (ADR-0003). Curated suggestions are safe by
  # construction, so most input never needs moderation, and an optional slot's
  # `default` is the sensible value used when a child skips it. The Subject has
  # no default: it is required and cannot be skipped.
  Slot = Data.define(:key, :question, :suggestions, :default) do
    def required? = default.nil?
    def optional? = !required?
  end

  SLOTS = [
    Slot.new("subject", "What would you like to draw?",
      [ "a dragon", "a cat", "a rocket", "a unicorn", "a dinosaur", "a robot" ], nil),
    Slot.new("action", "What is it doing?",
      [ "flying", "running", "jumping", "sleeping", "dancing" ], "just being itself"),
    Slot.new("mood", "Is it silly or serious?",
      [ "silly", "happy", "brave", "sleepy", "grumpy" ], "happy"),
    Slot.new("background", "What's behind it?",
      [ "the sky", "a forest", "outer space", "under the sea" ], "no background")
  ].freeze

  # Subject is required the moment the Plan leaves the chat — it's the one slot
  # that can't be skipped, and generation depends on it.
  validates :subject, presence: true, unless: :building?

  # The next unanswered question, or nil once every slot is filled.
  def next_slot
    SLOTS.find { |slot| self[slot.key].blank? }
  end

  # The conversation state the chat page renders: the transcript so far, the
  # current question (nil once complete), the assembled Plan on completion, and —
  # when the last free-text Subject was refused — a gentle redirect notice that
  # steers the child back to the safe suggestion chips (ADR-0003).
  REDIRECT_MESSAGE = "Let's draw something fun instead — how about one of these?"

  def as_chat
    {
      id: id,
      status: status,
      answers: SLOTS.select { |slot| self[slot.key].present? }
        .map { |slot| { key: slot.key, question: slot.question, value: self[slot.key] } },
      question: next_slot && {
        key: next_slot.key,
        prompt: next_slot.question,
        suggestions: next_slot.suggestions,
        optional: next_slot.optional?
      },
      plan: building? ? nil : { subject:, action:, mood:, background:, age_band: },
      redirect: redirect_notice
    }
  end

  # The gentle redirect shown while the chat is still asking for a Subject after
  # a refusal. Nil once the Subject is filled (the question moves on) or when no
  # free-text Subject has been refused. The off-limits text is never echoed back
  # to the child — only the nudge toward the curated chips.
  def redirect_notice
    { message: REDIRECT_MESSAGE } if next_slot&.key == "subject" && subject_rejections.exists?
  end

  # The confirmed Plan attributes handed across the generation seam (ADR-0006).
  # Age Band is included so the generator can scale Step granularity by age.
  def attributes_for_generation
    { subject:, action:, mood:, background:, age_band: }
  end

  # Hand the Plan to the background generator: flip to generating and enqueue the
  # job (ADR-0009). Allowed from completed (first submission), failed (a retry
  # after the generator gave up), or ready-but-unconfirmed (the child previewed
  # the candidate and asked to try again, ADR-0002). In the last case the unloved
  # candidate is discarded first, so only the newest preview ever survives. A
  # no-op otherwise, so a double click, an in-flight generation, or a confirmed
  # drawing never enqueues twice.
  def submit_for_generation
    return false unless completed? || failed? || replaceable_candidate?

    discard_candidate
    generating!
    GenerateDirectedDrawingJob.perform_later(self)
    true
  end

  # The status the wait screen polls (ADR-0009): the lifecycle state, the
  # produced drawing's id, and — once ready and awaiting confirmation — the
  # candidate's render payload so the gate can show the finished picture
  # full-color before any stepping (ADR-0002).
  def as_generation
    { id:, status:, directed_drawing_id:, drawing: unconfirmed_candidate&.as_walkthrough }
  end

  # Record the child's answer (a chip or free text) for the current question,
  # completing the Plan once the last slot is filled. Blank answers are rejected
  # so the required Subject is never lost. Returns false when there's nothing to
  # answer or the answer is empty.
  #
  # A free-text or transcribed-voice **Subject** is classified by the safety gate
  # before it's accepted (ADR-0003); a `curated:` answer (a suggestion chip, safe
  # by construction) bypasses the gate. Only the Subject slot is gated — the
  # optional slots are never classified.
  def answer(value, curated: false)
    slot = next_slot
    typed = value.to_s.strip
    return false if slot.nil? || typed.blank?
    return fill(slot, typed) if curated || slot.key != "subject"

    gate_subject(slot, typed)
  end

  # Skip the current optional question, accepting its sensible default. The
  # required Subject has no default, so skipping it is refused.
  def skip
    slot = next_slot
    fill(slot, slot&.default)
  end

  private

  # The candidate awaiting the confirmation gate: the produced drawing while it's
  # still unconfirmed. Nil before generation finishes and again once confirmed.
  def unconfirmed_candidate
    directed_drawing unless directed_drawing&.confirmed?
  end

  # A ready Plan still showing an unconfirmed candidate can be regenerated; a
  # confirmed drawing is final and must not be replaced.
  def replaceable_candidate?
    ready? && unconfirmed_candidate.present?
  end

  # Drop the unconfirmed candidate before a regeneration so the replaced preview
  # leaves nothing behind. The owning reference is cleared first, then the row
  # (and its Steps) destroyed.
  def discard_candidate
    candidate = unconfirmed_candidate or return

    self.directed_drawing = nil
    candidate.destroy!
  end

  def fill(slot, value)
    return false if slot.nil? || value.blank?

    self[slot.key] = value
    self.status = :completed if next_slot.nil?
    save
  end

  # Run a free-text Subject through the safety gate (ADR-0003): fill the slot on
  # allow, or on deny record the rejection and leave the Subject blank so the
  # chat re-asks it with a gentle redirect notice. A denial is a redirect, not an
  # error — it returns truthy so the controller never attaches an "answer" error.
  def gate_subject(slot, typed)
    verdict = subject_safety_gate.call(typed)
    return fill(slot, typed) if verdict.allowed?

    subject_rejections.create!(subject: typed, profile: profile)
    true
  end
end
