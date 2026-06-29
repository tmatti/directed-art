# frozen_string_literal: true

require "test_helper"

class DrawingPlansTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
    @session = users(:one).sessions.last
    @session.update!(active_profile: profiles(:mia))
  end

  def start_plan
    post drawing_plans_path
    DrawingPlan.last
  end

  # Swap the Subject safety gate for the duration of a block, restoring the
  # suite default in teardown so one test's stub can't leak into another
  # (mirrors the generation seam's swap-and-restore convention).
  def with_safety_gate(gate)
    original = DrawingPlan.subject_safety_gate
    DrawingPlan.subject_safety_gate = gate
    yield
  ensure
    DrawingPlan.subject_safety_gate = original
  end

  # --- Starting the conversation ---

  test "POST create starts a building plan for the active profile and asks Subject first" do
    assert_difference -> { DrawingPlan.count }, 1 do
      post drawing_plans_path
    end
    plan = DrawingPlan.last
    assert_redirected_to drawing_plan_path(plan)
    assert plan.building?
    assert_equal profiles(:mia), plan.profile
    assert_equal profiles(:mia).age_band, plan.age_band
  end

  test "the age band is taken from the profile, never asked" do
    plan = start_plan
    get drawing_plan_path(plan)
    keys = inertia.props[:plan][:answers].map { |a| a[:key] } +
           [ inertia.props[:plan][:question][:key] ]
    assert_not_includes keys, "age_band"
  end

  test "GET show renders the current question with suggestion chips" do
    plan = start_plan
    get drawing_plan_path(plan)
    assert_response :success

    question = inertia.props[:plan][:question]
    assert_equal "subject", question[:key]
    assert_equal "What would you like to draw?", question[:prompt]
    assert question[:suggestions].any?
    assert_equal false, question[:optional]
    assert_equal "building", inertia.props[:plan][:status]
  end

  # --- Assembling a complete Plan ---

  test "assembles a complete Plan one answer at a time, then shows a summary" do
    plan = start_plan

    patch drawing_plan_path(plan), params: { answer: "a dragon" }
    assert_equal "action", plan.reload.next_slot.key

    patch drawing_plan_path(plan), params: { answer: "flying" }
    patch drawing_plan_path(plan), params: { answer: "silly" }
    patch drawing_plan_path(plan), params: { answer: "the sky" }

    assert plan.reload.completed?
    assert_equal %w[a\ dragon flying silly the\ sky],
      [ plan.subject, plan.action, plan.mood, plan.background ]

    get drawing_plan_path(plan)
    summary = inertia.props[:plan][:plan]
    assert_equal "a dragon", summary[:subject]
    assert_equal "the sky", summary[:background]
    assert_nil inertia.props[:plan][:question]
  end

  test "free-text answers are accepted alongside chips" do
    plan = start_plan
    patch drawing_plan_path(plan), params: { answer: "  a friendly robot " }
    assert_equal "a friendly robot", plan.reload.subject
  end

  # --- Skipping optional slots ---

  test "optional slots can be skipped and receive sensible defaults" do
    plan = start_plan
    patch drawing_plan_path(plan), params: { answer: "a cat" }
    patch drawing_plan_path(plan), params: { skip: "1" }
    patch drawing_plan_path(plan), params: { skip: "1" }
    patch drawing_plan_path(plan), params: { skip: "1" }

    plan.reload
    assert plan.completed?
    assert_equal "a cat", plan.subject
    assert plan.action.present?
    assert plan.mood.present?
    assert plan.background.present?
  end

  test "the conversation completes only when Subject is filled" do
    plan = start_plan
    patch drawing_plan_path(plan), params: { skip: "1" }

    plan.reload
    assert plan.building?
    assert_nil plan.subject
    assert_equal "subject", plan.next_slot.key
  end

  test "a blank Subject is rejected with an error" do
    plan = start_plan
    patch drawing_plan_path(plan), params: { answer: "   " }
    assert plan.reload.building?
    assert_nil plan.subject
  end

  # --- Profile / account scoping (ADR-0004) ---

  test "persistence is scoped to the active profile" do
    plan = start_plan
    assert_equal profiles(:mia).id, plan.profile_id
  end

  test "cannot view a plan belonging to another profile in the same account" do
    leos = profiles(:leo).drawing_plans.create!(age_band: profiles(:leo).age_band)
    get drawing_plan_path(leos)
    assert_response :not_found
  end

  test "cannot answer another profile's plan" do
    others = profiles(:other_kid).drawing_plans.create!(age_band: profiles(:other_kid).age_band)
    patch drawing_plan_path(others), params: { answer: "a dragon" }
    assert_response :not_found
    assert_nil others.reload.subject
  end

  # --- Subject safety gate (ADR-0003) ---

  test "a free-text Subject is classified by the gate and accepted when allowed" do
    gate = FakeSubjectSafetyGate.new(allow: true)
    plan = start_plan

    with_safety_gate(gate) do
      patch drawing_plan_path(plan), params: { answer: "a friendly dragon" }
    end

    assert_equal "a friendly dragon", plan.reload.subject
    assert_equal "action", plan.reload.next_slot.key
    assert_equal "a friendly dragon", gate.last_subject
  end

  test "an off-limits free-text Subject is gently redirected, not errored, and logged" do
    gate = FakeSubjectSafetyGate.new(allow: false)
    plan = start_plan

    assert_difference -> { SubjectRejection.count }, 1 do
      with_safety_gate(gate) do
        patch drawing_plan_path(plan), params: { answer: "something scary" }
      end
    end

    plan.reload
    assert_nil plan.subject
    assert plan.building?
    assert_equal "subject", plan.next_slot.key
    assert_redirected_to drawing_plan_path(plan)

    # redirected, not errored: no error is attached to the answer field
    assert_nil session[:inertia_errors]

    # the chat re-asks Subject with a gentle redirect notice
    get drawing_plan_path(plan)
    assert_equal "subject", inertia.props[:plan][:question][:key]
    assert_not_nil inertia.props[:plan][:redirect]
    assert_kind_of String, inertia.props[:plan][:redirect][:message]

    # the rejected Subject is logged to tune from real data
    rejection = SubjectRejection.find_by!(subject: "something scary")
    assert_equal plan, rejection.drawing_plan
    assert_equal profiles(:mia), rejection.profile
  end

  test "a suggestion-chip Subject bypasses the gate and is accepted without classification" do
    # A gate that denies everything: chips must still go through, because they're
    # curated safe-by-construction (ADR-0003, layer 1).
    gate = FakeSubjectSafetyGate.new(allow: false)
    plan = start_plan

    assert_no_difference -> { SubjectRejection.count } do
      with_safety_gate(gate) do
        patch drawing_plan_path(plan), params: { answer: "a dragon", from_chip: "1" }
      end
    end

    assert_equal "a dragon", plan.reload.subject
    assert_equal "action", plan.reload.next_slot.key
    assert_nil gate.last_subject
  end

  # --- Guards ---

  test "requires authentication" do
    sign_out
    post drawing_plans_path
    assert_redirected_to sign_in_path
  end

  test "redirects to the profile picker when no profile is active" do
    @session.update!(active_profile: nil)
    post drawing_plans_path
    assert_redirected_to active_profile_path
  end
end
