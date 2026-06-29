# frozen_string_literal: true

# The guided planning chat. Assembles a Drawing Plan for the active Profile one
# question at a time (Subject, then optional Action, Mood, Background), each
# answered by a suggestion chip or free text. Plans are scoped to the active
# Profile, so a child only ever builds their own (ADR-0004).
class DrawingPlansController < InertiaController
  include RequiresActiveProfile

  def create
    plan = Current.active_profile.drawing_plans.create!(age_band: Current.active_profile.age_band)
    redirect_to drawing_plan_path(plan)
  end

  def show
    plan = Current.active_profile.drawing_plans.find(params[:id])
    render inertia: { plan: plan.as_chat }
  end

  def update
    plan = Current.active_profile.drawing_plans.find(params[:id])
    curated = params[:from_chip] == "1"

    if params[:skip].present? ? plan.skip : plan.answer(params[:answer], curated: curated)
      redirect_to drawing_plan_path(plan)
    else
      redirect_to drawing_plan_path(plan),
        inertia: { errors: { answer: "Tell me what you'd like to draw!" } }
    end
  end
end
