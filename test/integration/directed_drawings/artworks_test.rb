# frozen_string_literal: true

require "test_helper"

# Artwork capture at the finish of a Walkthrough (ADR-0008, 0009): a child (or
# adult on their behalf) photographs their real paper drawing and uploads it as
# an Artwork attached to the Directed Drawing, stored via Active Storage on R2.
# The upload is optional and a drawing can collect many Artworks over time.
class DirectedDrawings::ArtworksTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
    @session = users(:one).sessions.last
    @session.update!(active_profile: profiles(:mia))
    @drawing = confirmed_drawing
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
          "primitives" => [ { "type" => "circle", "cx" => 300, "cy" => 300, "r" => 120 } ] }
      ]
    }
  end

  def photo_upload
    fixture_file_upload("test.png", "image/png")
  end

  # --- Uploading an Artwork ---

  test "POST create saves an Artwork with its photo attached to the drawing" do
    assert_difference -> { @drawing.artworks.count } => 1 do
      post directed_drawing_artworks_path(@drawing), params: { photo: photo_upload }
    end

    assert_redirected_to directed_drawing_path(@drawing)
    artwork = @drawing.artworks.last
    assert artwork.photo.attached?
    assert_equal "test.png", artwork.photo.filename.to_s
  end

  test "an uploaded Artwork is viewable on the drawing's walkthrough" do
    @drawing.artworks.create!(photo: photo_upload)

    get directed_drawing_path(@drawing)
    assert_response :success

    artworks = inertia.props[:artworks]
    assert_equal 1, artworks.size
    assert_equal @drawing.artworks.last.id, artworks.first[:id]
    assert artworks.first[:photo_url].present?
  end

  test "a drawing can collect many Artworks over time (repeat)" do
    2.times { @drawing.artworks.create!(photo: photo_upload) }

    post directed_drawing_artworks_path(@drawing), params: { photo: photo_upload }
    assert_redirected_to directed_drawing_path(@drawing)
    assert_equal 3, @drawing.reload.artworks.count
  end

  # --- Profile / account scoping (ADR-0004) ---

  test "cannot upload to another profile's drawing in the same account" do
    leos = confirmed_drawing(profile: profiles(:leo))

    assert_no_difference -> { leos.artworks.count } do
      post directed_drawing_artworks_path(leos), params: { photo: photo_upload }
    end

    assert_response :not_found
  end

  test "cannot upload to another account's drawing" do
    others = confirmed_drawing(profile: profiles(:other_kid))

    assert_no_difference -> { others.artworks.count } do
      post directed_drawing_artworks_path(others), params: { photo: photo_upload }
    end

    assert_response :not_found
  end

  test "cannot view another profile's artworks through the walkthrough" do
    leos = confirmed_drawing(profile: profiles(:leo))
    leos.artworks.create!(photo: photo_upload)

    get directed_drawing_path(leos)
    assert_response :not_found
  end

  # --- Only confirmed drawings accept uploads (ADR-0002) ---

  test "an unconfirmed candidate does not accept an Artwork upload" do
    candidate = DirectedDrawing.create_from_plan!(profile: profiles(:mia), plan: plan)

    assert_no_difference -> { candidate.artworks.count } do
      post directed_drawing_artworks_path(candidate), params: { photo: photo_upload }
    end

    assert_response :not_found
  end

  # --- Guards ---

  test "requires authentication" do
    sign_out
    post directed_drawing_artworks_path(@drawing), params: { photo: photo_upload }
    assert_redirected_to sign_in_path
  end

  test "redirects to the profile picker when no profile is active" do
    @session.update!(active_profile: nil)
    post directed_drawing_artworks_path(@drawing), params: { photo: photo_upload }
    assert_redirected_to active_profile_path
  end
end
