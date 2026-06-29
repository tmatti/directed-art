# frozen_string_literal: true

module DrawingPlans
  # Submits a Drawing Plan for background generation and serves the wait screen
  # the child watches while the Directed Drawing is produced (ADR-0009). Both
  # actions are scoped to the active Profile, so a child only ever generates from
  # their own Plan (ADR-0004).
  class GenerationsController < InertiaController
    include RequiresActiveProfile

    # Enqueue generation, then hand off to the polling wait screen. A Plan that
    # isn't ready to submit (still building, or already produced its drawing) is
    # sent somewhere terminal instead, so the wait screen never polls forever.
    def create
      plan.submit_for_generation

      if plan.generating?
        redirect_to drawing_plan_generation_path(plan)
      elsif plan.ready?
        redirect_to directed_drawing_path(plan.directed_drawing)
      else
        redirect_to drawing_plan_path(plan)
      end
    end

    # The status the wait screen polls: pending while the job runs, ready (with
    # the produced drawing's id) once it finishes, or failed if it gave up.
    def show
      render inertia: { generation: plan.as_generation }
    end

    private

    def plan
      @plan ||= Current.active_profile.drawing_plans.find(params[:drawing_plan_id])
    end
  end
end
