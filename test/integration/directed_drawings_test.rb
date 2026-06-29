# frozen_string_literal: true

require "test_helper"

class DirectedDrawingsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
    @session = users(:one).sessions.last
    @session.update!(active_profile: profiles(:mia))
    @drawing = confirmed_drawing
  end

  # Only a confirmed Directed Drawing is a steppable Walkthrough (ADR-0002), so
  # the Walkthrough surfaces are exercised with confirmed drawings.
  def confirmed_drawing(profile: profiles(:mia))
    DirectedDrawing.create_from_plan!(profile: profile, plan: plan).tap(&:confirm!)
  end

  def plan
    {
      "subject" => "a happy sun",
      "title" => "Let's draw a happy sun!",
      "canvas" => { "width" => 600, "height" => 600 },
      "steps" => [
        { "instruction" => "Draw a circle.", "narration" => "Big round circle!",
          "primitives" => [ { "type" => "circle", "cx" => 300, "cy" => 300, "r" => 120 } ] },
        { "instruction" => "Add rays.", "narration" => "Pointy rays!",
          "primitives" => [ { "type" => "polygon", "points" => [ [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ] } ] }
      ]
    }
  end

  # --- Serving the Walkthrough to the active Profile ---

  test "GET show serves the active profile's drawing with its steps" do
    get directed_drawing_path(@drawing)
    assert_response :success

    drawing = inertia.props[:drawing]
    assert_equal @drawing.id, drawing[:id]
    assert_equal "Let's draw a happy sun!", drawing[:title]
    assert_equal 2, drawing[:steps].size
    assert_equal "Draw a circle.", drawing[:steps].first[:instruction]
    assert_equal profiles(:mia).id, inertia.props[:profile][:id]
  end

  test "GET index lists the active profile's drawings" do
    get directed_drawings_path
    assert_response :success
    ids = inertia.props[:drawings].map { |d| d[:id] }
    assert_includes ids, @drawing.id
  end

  # --- Profile / account scoping (ADR-0004) ---

  test "cannot view a drawing belonging to another profile in the same account" do
    leos = confirmed_drawing(profile: profiles(:leo))
    get directed_drawing_path(leos)
    assert_response :not_found
  end

  test "cannot view another account's drawing" do
    others = confirmed_drawing(profile: profiles(:other_kid))
    get directed_drawing_path(others)
    assert_response :not_found
  end

  test "index only lists the active profile's drawings" do
    leos = confirmed_drawing(profile: profiles(:leo))
    get directed_drawings_path
    ids = inertia.props[:drawings].map { |d| d[:id] }
    assert_includes ids, @drawing.id
    assert_not_includes ids, leos.id
  end

  # --- Only confirmed drawings are steppable (ADR-0002) ---

  test "an unconfirmed candidate is not a steppable Walkthrough" do
    candidate = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)
    get directed_drawing_path(candidate)
    assert_response :not_found
  end

  test "an unconfirmed candidate is not listed in the index" do
    candidate = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)
    get directed_drawings_path
    ids = inertia.props[:drawings].map { |d| d[:id] }
    assert_not_includes ids, candidate.id
  end

  test "current_step cannot be persisted for an unconfirmed candidate" do
    candidate = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)
    patch directed_drawing_current_step_path(candidate), params: { current_step: 1 }
    assert_response :not_found
    assert_equal 0, candidate.reload.current_step
  end

  # --- Resumable current_step ---

  test "PATCH current_step persists the position" do
    patch directed_drawing_current_step_path(@drawing), params: { current_step: 2 }
    assert_redirected_to directed_drawing_path(@drawing)
    assert_equal 2, @drawing.reload.current_step
  end

  test "the walkthrough resumes at the saved step" do
    patch directed_drawing_current_step_path(@drawing), params: { current_step: 1 }

    get directed_drawing_path(@drawing)
    assert_equal 1, inertia.props[:drawing][:current_step]
  end

  test "current_step is clamped to the finish page" do
    patch directed_drawing_current_step_path(@drawing), params: { current_step: 99 }
    assert_equal @drawing.last_page, @drawing.reload.current_step
  end

  test "current_step is clamped to the cover" do
    patch directed_drawing_current_step_path(@drawing), params: { current_step: -5 }
    assert_equal 0, @drawing.reload.current_step
  end

  # --- Guards ---

  test "requires authentication" do
    sign_out
    get directed_drawing_path(@drawing)
    assert_redirected_to sign_in_path
  end

  test "redirects to the profile picker when no profile is active" do
    @session.update!(active_profile: nil)
    get directed_drawing_path(@drawing)
    assert_redirected_to active_profile_path
  end
end
