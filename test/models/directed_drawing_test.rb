# frozen_string_literal: true

require "test_helper"

class DirectedDrawingTest < ActiveSupport::TestCase
  def plan
    {
      "subject" => "a happy sun",
      "title" => "Let's draw a happy sun!",
      "ageBand" => "7-10",
      "canvas" => { "width" => 600, "height" => 600 },
      "steps" => [
        { "instruction" => "Draw a circle.", "narration" => "Big round circle!",
          "primitives" => [ { "type" => "circle", "cx" => 300, "cy" => 300, "r" => 120 } ] },
        { "instruction" => "Add rays.", "narration" => "Pointy rays!",
          "primitives" => [ { "type" => "polygon", "points" => [ [ 300, 150 ], [ 285, 180 ], [ 315, 180 ] ] } ] }
      ]
    }
  end

  test "create_from_plan! builds the drawing and ordered steps" do
    drawing = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)

    assert_equal "a happy sun", drawing.subject
    assert_equal "Let's draw a happy sun!", drawing.title
    assert_equal 600, drawing.canvas_width
    assert_equal 600, drawing.canvas_height
    assert_equal 0, drawing.current_step

    assert_equal [ 1, 2 ], drawing.steps.map(&:position)
    assert_equal "Draw a circle.", drawing.steps.first.instruction
    assert_equal "Big round circle!", drawing.steps.first.narration
    assert_equal "circle", drawing.steps.first.primitives.first["type"]
  end

  test "the age band is taken from the profile, not the plan" do
    drawing = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)

    assert_equal "ages_4_6", drawing.age_band
    assert_equal profiles(:mia).age_band, drawing.age_band
  end

  test "canvas dimensions default to 600 when the plan omits them" do
    drawing = DirectedDrawing.create_from_plan!(
      profile: profiles(:mia), plan: plan.except("canvas")
    )

    assert_equal 600, drawing.canvas_width
    assert_equal 600, drawing.canvas_height
  end

  test "last_page is one past the final step (the finish page)" do
    drawing = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)

    assert_equal 3, drawing.last_page
  end

  test "as_walkthrough exposes the renderer payload" do
    drawing = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)
    payload = drawing.as_walkthrough

    assert_equal drawing.id, payload[:id]
    assert_equal "Let's draw a happy sun!", payload[:title]
    assert_equal({ width: 600, height: 600 }, payload[:canvas])
    assert_equal 2, payload[:steps].size
    assert_equal "Draw a circle.", payload[:steps].first[:instruction]
    assert_equal "circle", payload[:steps].first[:primitives].first["type"]
  end

  test "requires a subject and a title" do
    drawing = profiles(:mia).directed_drawings.build(age_band: :ages_4_6)
    assert_not drawing.valid?
    assert_includes drawing.errors[:subject], "can't be blank"
    assert_includes drawing.errors[:title], "can't be blank"
  end

  test "destroying the drawing destroys its steps" do
    drawing = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)

    assert_difference -> { Step.count }, -2 do
      drawing.destroy
    end
  end

  test "destroying the owning profile destroys its drawings" do
    DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)

    assert_difference -> { DirectedDrawing.count }, -1 do
      profiles(:mia).destroy
    end
  end
end
