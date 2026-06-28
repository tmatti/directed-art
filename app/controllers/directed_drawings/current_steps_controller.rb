# frozen_string_literal: true

module DirectedDrawings
  # Persists the resumable Walkthrough position for the active Profile's drawing.
  class CurrentStepsController < InertiaController
    include RequiresActiveProfile

    def update
      drawing = Current.active_profile.directed_drawings.find(params[:directed_drawing_id])
      drawing.update!(current_step: params[:current_step].to_i.clamp(0, drawing.last_page))
      redirect_to directed_drawing_path(drawing)
    end
  end
end
