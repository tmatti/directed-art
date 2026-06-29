# frozen_string_literal: true

require "test_helper"

class DrawingPlanTest < ActiveSupport::TestCase
  setup do
    @plan = profiles(:mia).drawing_plans.create!(age_band: profiles(:mia).age_band)
  end

  # --- The slot-filling conversation (ADR-0003) ---

  test "starts building, asking for the Subject first" do
    assert @plan.building?
    assert_equal "subject", @plan.next_slot.key
    assert @plan.next_slot.required?
  end

  test "asks one question at a time in slot order" do
    assert_equal "subject", @plan.next_slot.key
    @plan.answer("a dragon")
    assert_equal "action", @plan.next_slot.key
    @plan.answer("flying")
    assert_equal "mood", @plan.next_slot.key
    @plan.answer("silly")
    assert_equal "background", @plan.next_slot.key
  end

  test "completes once every slot is filled, with a summary" do
    @plan.answer("a dragon")
    @plan.answer("flying")
    @plan.answer("silly")
    assert @plan.building?
    @plan.answer("the sky")

    assert @plan.completed?
    assert_nil @plan.next_slot
    assert_equal "a dragon", @plan.subject
    assert_equal "flying", @plan.action
    assert_equal "silly", @plan.mood
    assert_equal "the sky", @plan.background
  end

  test "optional slots can be skipped and receive sensible defaults" do
    @plan.answer("a cat")
    @plan.skip
    @plan.skip
    @plan.skip

    assert @plan.completed?
    assert_equal "a cat", @plan.subject
    assert_equal DrawingPlan::SLOTS[1].default, @plan.action
    assert_equal DrawingPlan::SLOTS[2].default, @plan.mood
    assert_equal DrawingPlan::SLOTS[3].default, @plan.background
    assert @plan.action.present?
    assert @plan.mood.present?
    assert @plan.background.present?
  end

  test "the required Subject cannot be skipped" do
    assert_not @plan.skip
    assert @plan.building?
    assert_equal "subject", @plan.next_slot.key
    assert_nil @plan.subject
  end

  test "a blank answer is rejected and does not advance" do
    assert_not @plan.answer("   ")
    assert_equal "subject", @plan.next_slot.key
  end

  test "free-text answers are trimmed" do
    @plan.answer("  a friendly robot  ")
    assert_equal "a friendly robot", @plan.subject
  end

  test "answering past completion does nothing" do
    @plan.answer("a cat")
    @plan.skip
    @plan.skip
    @plan.skip
    assert @plan.completed?

    assert_not @plan.answer("a dog")
    assert_equal "a cat", @plan.subject
  end

  # --- Age Band is derived from the Profile, never asked ---

  test "the age band is taken from the profile" do
    assert_equal profiles(:mia).age_band, @plan.age_band
    assert_not_includes DrawingPlan::SLOTS.map(&:key), "age_band"
  end

  test "a completed plan requires a subject" do
    @plan.update!(subject: "a cat")
    @plan.action = "running"
    @plan.mood = "happy"
    @plan.background = "none"
    @plan.subject = nil
    @plan.status = :completed
    assert_not @plan.valid?
    assert_includes @plan.errors[:subject], "can't be blank"
  end

  # --- The wait-screen / confirmation-gate payload (ADR-0009, ADR-0002) ---

  def candidate_drawing
    DirectedDrawing.create_from_plan!(
      profile: profiles(:mia),
      plan: {
        "subject" => "a dragon", "title" => "Let's draw a dragon!",
        "steps" => [
          { "instruction" => "Draw a circle.",
            "primitives" => [ { "type" => "circle", "cx" => 300, "cy" => 300, "r" => 120 } ] }
        ]
      }
    )
  end

  test "as_generation carries no candidate drawing while still generating" do
    @plan.update!(subject: "a dragon", status: :generating)

    payload = @plan.as_generation
    assert_equal "generating", payload[:status]
    assert_nil payload[:directed_drawing_id]
    assert_nil payload[:drawing]
  end

  test "as_generation reveals the candidate's cover once ready for confirmation" do
    drawing = candidate_drawing
    @plan.update!(subject: "a dragon", status: :ready, directed_drawing: drawing)

    payload = @plan.as_generation
    assert_equal "ready", payload[:status]
    assert_equal drawing.id, payload[:directed_drawing_id]
    assert_equal drawing.id, payload[:drawing][:id]
    assert_equal "Let's draw a dragon!", payload[:drawing][:title]
    assert payload[:drawing][:steps].any?
  end

  test "as_generation hides the drawing once it has been confirmed" do
    drawing = candidate_drawing
    drawing.confirm!
    @plan.update!(subject: "a dragon", status: :ready, directed_drawing: drawing)

    assert_nil @plan.as_generation[:drawing]
  end

  # --- Scoping ---

  test "belongs to a profile and is destroyed with it" do
    profiles(:mia).drawing_plans.create!(age_band: profiles(:mia).age_band, subject: "a cat")
    assert_difference -> { DrawingPlan.count }, -2 do
      profiles(:mia).destroy
    end
  end
end
