# frozen_string_literal: true

# The faked `DrawingGenerator` from slice #5: returns the canned spike drawing,
# re-titled for the requested subject, proving the whole async pipeline with
# zero model risk (ADR-0006, ADR-0009). Tests inject this behind the generation
# seam so every flow runs deterministically without a live model. The real
# RubyLLM-backed `DrawingGenerator` is the production default; this fake is the
# test default, wired in `test_helper.rb`.
class FakeDrawingGenerator
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
