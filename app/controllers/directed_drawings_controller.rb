# frozen_string_literal: true

# Serves a Profile's Directed Drawings and renders the Walkthrough. Drawings are
# scoped to the active Profile, so a child only sees their own (ADR-0004).
class DirectedDrawingsController < InertiaController
  include RequiresActiveProfile

  def index
    render inertia: {
      drawings: Current.active_profile.directed_drawings.order(:created_at)
        .as_json(only: %i[id subject title current_step])
    }
  end

  def show
    drawing = Current.active_profile.directed_drawings.find(params[:id])

    render inertia: {
      drawing: drawing.as_walkthrough,
      profile: Current.active_profile.as_json(only: %i[id name])
    }
  end
end
