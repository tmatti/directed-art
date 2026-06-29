# frozen_string_literal: true

# The generation seam: input is the confirmed Drawing Plan attributes, output is
# a structured drawing in the Primitive DSL (ADR-0001, ADR-0005). This is the
# one injected boundary behind which all LLM concerns live (ADR-0006) — the job
# calls `#call` and validates the result, never knowing how it was produced.
#
# For this slice the generator is FAKED: it returns the canned spike drawing,
# re-titled for the requested subject, proving the whole async pipeline with
# zero model risk. The real RubyLLM-backed generator drops in behind this same
# seam without the job, validator, or polling changing.
class DrawingGenerator
  CANNED_DRAWING = Rails.root.join("db/seed_drawings/happy_sun.json")

  # Returns a structured-drawing hash (string keys, as parsed from JSON) for the
  # given plan attributes (subject, action, mood, background, age_band).
  def call(plan)
    JSON.parse(CANNED_DRAWING.read).merge(
      "subject" => plan[:subject],
      "title" => "Let's draw #{plan[:subject]}!"
    )
  end
end
