# frozen_string_literal: true

require "test_helper"

# Repeating a Directed Drawing (ADR-0008 — a DirectedDrawing has many Artworks).
# A child can re-walk an existing, confirmed DirectedDrawing from the start,
# and upload another Artwork at the finish, so one drawing collects many
# Artworks over time — all surfaced in the per-Profile gallery.
class DirectedDrawings::RepeatsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
    @session = users(:one).sessions.last
    @session.update!(active_profile: profiles(:mia))
    @drawing = confirmed_drawing
    # Walk the drawing all the way to the finish page before each test, so a
    # repeat has a saved position worth resetting.
    @drawing.update!(current_step: @drawing.last_page)
  end

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

  def photo_upload
    fixture_file_upload("test.png", "image/png")
  end

  # --- Re-walking from the start ---

  test "POST repeat resets the Walkthrough to the start and re-enters it" do
    assert_equal @drawing.last_page, @drawing.current_step

    post directed_drawing_repeat_path(@drawing)

    assert_redirected_to directed_drawing_path(@drawing)
    assert_equal 0, @drawing.reload.current_step
  end

  test "after a repeat the Walkthrough is served from the cover again" do
    post directed_drawing_repeat_path(@drawing)

    get directed_drawing_path(@drawing)
    assert_equal 0, inertia.props[:drawing][:current_step]
  end

  # --- A repeat accumulates another Artwork (ADR-0008) ---

  test "after repeating, finishing again can add another Artwork to the same drawing" do
    @drawing.artworks.create!(photo: photo_upload)
    assert_equal 1, @drawing.artworks.count

    # Repeat: back to the start, walk to the finish, and photograph another.
    post directed_drawing_repeat_path(@drawing)
    assert_equal 0, @drawing.reload.current_step

    @drawing.update!(current_step: @drawing.last_page)
    post directed_drawing_artworks_path(@drawing), params: { photo: photo_upload }

    assert_redirected_to directed_drawing_path(@drawing)
    assert_equal 2, @drawing.reload.artworks.count
  end

  test "the gallery shows every Artwork a drawing has collected across repeats" do
    3.times do
      post directed_drawing_repeat_path(@drawing)
      @drawing.update!(current_step: @drawing.last_page)
      post directed_drawing_artworks_path(@drawing), params: { photo: photo_upload }
    end

    get directed_drawings_path
    assert_response :success

    entry = inertia.props[:drawings].find { |d| d[:id] == @drawing.id }
    assert_equal 3, entry[:artworks].length
  end

  # --- Only confirmed drawings can be repeated (ADR-0002) ---

  test "an unconfirmed candidate cannot be repeated" do
    candidate = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)

    assert_no_difference -> { candidate.reload.current_step } do
      post directed_drawing_repeat_path(candidate)
    end

    assert_response :not_found
    assert_equal 0, candidate.current_step
  end

  # --- Profile / account scoping (ADR-0004) ---

  test "cannot repeat another profile's drawing in the same account" do
    leos = confirmed_drawing(profile: profiles(:leo))

    assert_no_difference -> { leos.reload.current_step } do
      post directed_drawing_repeat_path(leos)
    end

    assert_response :not_found
  end

  test "cannot repeat another account's drawing" do
    others = confirmed_drawing(profile: profiles(:other_kid))

    assert_no_difference -> { others.reload.current_step } do
      post directed_drawing_repeat_path(others)
    end

    assert_response :not_found
  end

  # --- Guards ---

  test "requires authentication" do
    sign_out
    post directed_drawing_repeat_path(@drawing)
    assert_redirected_to sign_in_path
  end

  test "redirects to the profile picker when no profile is active" do
    @session.update!(active_profile: nil)
    post directed_drawing_repeat_path(@drawing)
    assert_redirected_to active_profile_path
  end
end
