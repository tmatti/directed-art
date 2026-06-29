# frozen_string_literal: true

# Turns a confirmed Drawing Plan into a persisted Directed Drawing, off the web
# request (ADR-0009). It calls the DrawingGenerator seam, validates the result
# against the DSL schema, and — only when it's well-formed — persists the
# Directed Drawing and its Steps and marks the Plan ready. Malformed output is
# retried a few times (a transient bad generation shouldn't doom the request);
# once retries are exhausted the Plan is marked failed so the wait screen can
# stop polling.
class GenerateDirectedDrawingJob < ApplicationJob
  queue_as :default

  # The generation seam (ADR-0006). Defaults to the faked generator for this
  # slice; tests inject their own, and the real RubyLLM generator swaps in here
  # without the rest of the pipeline changing.
  class_attribute :generator, default: DrawingGenerator.new

  # The number of generation attempts before giving up on a Plan. Each malformed
  # result re-enqueues; the final failure marks the Plan failed.
  ATTEMPTS = 3

  retry_on DrawingSchema::InvalidDrawing, attempts: ATTEMPTS do |job, _error|
    job.arguments.first.failed!
  end

  # A Plan deleted (or its Profile removed) before the job runs is simply dropped.
  discard_on ActiveJob::DeserializationError

  def perform(plan)
    drawing_json = DrawingSchema.validate!(generator.call(plan.attributes_for_generation))

    drawing = DirectedDrawing.create_from_plan!(profile: plan.profile, plan: drawing_json)
    plan.update!(directed_drawing: drawing, status: :ready)
  rescue DrawingSchema::InvalidDrawing
    raise # The malformed-output contract: let retry_on retry, then fail the Plan.
  rescue StandardError
    # Any other failure: mark the Plan failed so the wait screen stops polling,
    # then re-raise so the error still surfaces to the queue for investigation.
    plan.failed!
    raise
  end
end
