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
  # current question (nil once complete), and the assembled Plan on completion.
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
      plan: building? ? nil : { subject:, action:, mood:, background:, age_band: }
    }
  end

  # The confirmed Plan attributes handed across the generation seam (ADR-0006).
  # Age Band is included so the generator can scale Step granularity by age.
  def attributes_for_generation
    { subject:, action:, mood:, background:, age_band: }
  end

  # Hand the Plan to the background generator: flip to generating and enqueue the
  # job (ADR-0009). Allowed from completed (first submission) or failed (a retry
  # after the generator gave up). A no-op otherwise, so a double click or an
  # already-generating Plan never enqueues twice.
  def submit_for_generation
    return false unless completed? || failed?

    generating!
    GenerateDirectedDrawingJob.perform_later(self)
    true
  end

  # The status the wait screen polls (ADR-0009): the lifecycle state plus the
  # produced drawing's id once ready, so the screen knows where to send the child.
  def as_generation
    { id:, status:, directed_drawing_id: }
  end

  # Record the child's answer (a chip or free text) for the current question,
  # completing the Plan once the last slot is filled. Blank answers are rejected
  # so the required Subject is never lost. Returns false when there's nothing to
  # answer or the answer is empty.
  def answer(value)
    fill(next_slot, value.to_s.strip)
  end

  # Skip the current optional question, accepting its sensible default. The
  # required Subject has no default, so skipping it is refused.
  def skip
    slot = next_slot
    fill(slot, slot&.default)
  end

  private

  def fill(slot, value)
    return false if slot.nil? || value.blank?

    self[slot.key] = value
    self.status = :completed if next_slot.nil?
    save
  end
end
