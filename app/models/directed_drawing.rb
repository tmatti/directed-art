# frozen_string_literal: true

# A complete, ordered sequence of Steps that guides a Profile to draw one
# subject on paper. Rendered as a Walkthrough: a full-color cover, one line-art
# Step page each, and a finish page (ADR-0008).
class DirectedDrawing < ApplicationRecord
  belongs_to :profile
  has_many :steps, -> { order(:position) }, dependent: :destroy, inverse_of: :directed_drawing

  enum :age_band, Profile::AGE_BANDS, validate: true

  validates :subject, presence: true
  validates :title, presence: true
  validates :current_step, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Imports a structured-drawing plan (the shape the spike validated, ADR-0005)
  # into a DirectedDrawing and its Steps. Keys are strings, as parsed from JSON.
  # The Age Band is taken from the Profile, never the plan (it's derived).
  def self.create_from_plan!(profile:, plan:)
    canvas = plan["canvas"] || {}

    create!(
      profile: profile,
      subject: plan["subject"],
      title: plan["title"],
      age_band: profile.age_band,
      canvas_width: canvas["width"] || 600,
      canvas_height: canvas["height"] || 600,
      steps: Array(plan["steps"]).map.with_index(1) do |step, position|
        Step.new(
          position: position,
          instruction: step["instruction"],
          narration: step["narration"],
          primitives: step["primitives"] || []
        )
      end
    )
  end

  # The last navigable page of the Walkthrough: the finish page sits one past the
  # final Step. Cover is page 0, Steps are 1..N, finish is N+1.
  def last_page
    steps.size + 1
  end

  # The Walkthrough payload the renderer consumes (ADR-0001).
  def as_walkthrough
    {
      id: id,
      subject: subject,
      title: title,
      current_step: current_step,
      canvas: { width: canvas_width, height: canvas_height },
      steps: steps.map do |step|
        {
          id: step.id,
          position: step.position,
          instruction: step.instruction,
          narration: step.narration,
          primitives: step.primitives
        }
      end
    }
  end
end
