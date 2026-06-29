# frozen_string_literal: true

require "test_helper"

# Drives the async generation pipeline end-to-end with the generator faked, so
# the whole architecture — seam, schema validation, retry, persistence — is
# proven deterministically without a real model (ADR-0006, ADR-0009).
class GenerateDirectedDrawingJobTest < ActiveJob::TestCase
  setup do
    @plan = profiles(:mia).drawing_plans.create!(
      age_band: profiles(:mia).age_band,
      subject: "a dragon", action: "flying", mood: "silly", background: "the sky",
      status: :generating
    )
  end

  teardown do
    # Restore the real (faked-for-this-slice) generator after any injection.
    GenerateDirectedDrawingJob.generator = DrawingGenerator.new
  end

  # A generator stub returning whatever it's given, counting its invocations so
  # tests can assert how many times the seam was driven.
  class StubGenerator
    attr_reader :calls

    def initialize(result)
      @result = result
      @calls = 0
    end

    def call(_plan)
      @calls += 1
      @result
    end
  end

  test "the faked generator drives the full flow: a valid drawing persists and the plan is marked ready" do
    assert_difference -> { DirectedDrawing.count } => 1, -> { Step.count } => 4 do
      perform_enqueued_jobs { GenerateDirectedDrawingJob.perform_now(@plan) }
    end

    @plan.reload
    assert @plan.ready?
    drawing = @plan.directed_drawing
    assert_not_nil drawing
    assert_equal "a dragon", drawing.subject
    assert_equal "Let's draw a dragon!", drawing.title
    assert_equal profiles(:mia), drawing.profile
    assert_equal profiles(:mia).age_band, drawing.age_band
    assert_equal 4, drawing.steps.size
  end

  test "a malformed generation is rejected, retried, and ultimately fails the plan" do
    stub = StubGenerator.new({ "subject" => "a dragon", "title" => "Oops", "steps" => [] })
    GenerateDirectedDrawingJob.generator = stub

    assert_no_difference -> { DirectedDrawing.count } do
      perform_enqueued_jobs { GenerateDirectedDrawingJob.perform_later(@plan) }
    end

    assert_equal GenerateDirectedDrawingJob::ATTEMPTS, stub.calls, "should retry up to the attempt limit"
    assert @plan.reload.failed?
  end

  test "a transient bad generation that later succeeds still produces a ready drawing" do
    valid = JSON.parse(DrawingGenerator::CANNED_DRAWING.read)
    flaky = Object.new
    flaky.define_singleton_method(:attempt) { @attempt = (@attempt || 0) + 1 }
    flaky.define_singleton_method(:call) do |_plan|
      attempt == 1 ? { "steps" => [] } : valid
    end
    GenerateDirectedDrawingJob.generator = flaky

    perform_enqueued_jobs { GenerateDirectedDrawingJob.perform_later(@plan) }

    assert @plan.reload.ready?
    assert_not_nil @plan.directed_drawing
  end

  test "an unexpected generation failure marks the plan failed and surfaces the error" do
    boom = Object.new
    boom.define_singleton_method(:call) { |_plan| raise "generator exploded" }
    GenerateDirectedDrawingJob.generator = boom

    assert_raises(RuntimeError) { GenerateDirectedDrawingJob.perform_now(@plan) }
    assert @plan.reload.failed?
  end

  test "submit_for_generation enqueues the job for a completed plan only" do
    completed = profiles(:mia).drawing_plans.create!(
      age_band: profiles(:mia).age_band,
      subject: "a cat", action: "x", mood: "y", background: "z", status: :completed
    )

    assert_enqueued_with(job: GenerateDirectedDrawingJob) do
      assert completed.submit_for_generation
    end
    assert completed.reload.generating?

    # Already submitted: no second enqueue.
    assert_no_enqueued_jobs do
      assert_not completed.submit_for_generation
    end
  end

  # --- Regeneration at the confirmation gate (ADR-0002) ---

  # A ready Plan whose unconfirmed candidate the child can preview, accept, or
  # ask to redraw.
  def ready_plan
    plan = profiles(:mia).drawing_plans.create!(
      age_band: profiles(:mia).age_band,
      subject: "a dragon", action: "flying", mood: "silly", background: "the sky",
      status: :generating
    )
    GenerateDirectedDrawingJob.perform_now(plan)
    plan.reload
  end

  test "submit_for_generation replaces an unconfirmed candidate and re-enqueues" do
    plan = ready_plan
    old_candidate = plan.directed_drawing
    assert_not old_candidate.confirmed?

    # One candidate discarded, one regenerated: the count nets out.
    assert_no_difference -> { DirectedDrawing.count } do
      assert_enqueued_with(job: GenerateDirectedDrawingJob) do
        assert plan.submit_for_generation
      end
      assert plan.reload.generating?
      perform_enqueued_jobs
    end

    plan.reload
    assert plan.ready?
    assert_not_equal old_candidate.id, plan.directed_drawing_id
    assert_nil DirectedDrawing.find_by(id: old_candidate.id),
      "the previous unconfirmed candidate is replaced"
  end

  test "submit_for_generation refuses to replace a confirmed drawing" do
    plan = ready_plan
    plan.directed_drawing.confirm!

    assert_no_enqueued_jobs do
      assert_not plan.submit_for_generation
    end
    assert plan.reload.ready?
    assert plan.directed_drawing.confirmed?
  end
end
