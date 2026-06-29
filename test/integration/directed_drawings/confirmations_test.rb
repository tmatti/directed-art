# frozen_string_literal: true

require "test_helper"

# The child-facing confirmation gate (ADR-0002): a generated candidate is
# previewed full-color, and "I love it!" turns it into a steppable Walkthrough.
class DirectedDrawings::ConfirmationsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
    @session = users(:one).sessions.last
    @session.update!(active_profile: profiles(:mia))
  end

  def candidate(profile: profiles(:mia))
    DirectedDrawing.create_from_plan!(
      profile: profile,
      plan: {
        "subject" => "a dragon", "title" => "Let's draw a dragon!",
        "steps" => [
          { "instruction" => "Draw a circle.",
            "primitives" => [ { "type" => "circle", "cx" => 300, "cy" => 300, "r" => 120 } ] }
        ]
      }
    )
  end

  test "POST confirmation confirms the candidate and enters its Walkthrough" do
    drawing = candidate
    assert_not drawing.confirmed?

    post directed_drawing_confirmation_path(drawing)

    assert_redirected_to directed_drawing_path(drawing)
    assert drawing.reload.confirmed?
  end

  test "a confirmed drawing becomes a steppable Walkthrough" do
    drawing = candidate
    post directed_drawing_confirmation_path(drawing)

    get directed_drawing_path(drawing)
    assert_response :success
    assert_equal drawing.id, inertia.props[:drawing][:id]
  end

  # --- Scoping (ADR-0004) ---

  test "cannot confirm another profile's candidate" do
    others = candidate(profile: profiles(:other_kid))
    post directed_drawing_confirmation_path(others)

    assert_response :not_found
    assert_not others.reload.confirmed?
  end

  # --- Guards ---

  test "requires authentication" do
    sign_out
    post directed_drawing_confirmation_path(candidate)
    assert_redirected_to sign_in_path
  end

  test "redirects to the profile picker when no profile is active" do
    @session.update!(active_profile: nil)
    post directed_drawing_confirmation_path(candidate)
    assert_redirected_to active_profile_path
  end
end
