# frozen_string_literal: true

module DirectedDrawings
  # The confirmation gate (ADR-0002): the child has previewed the finished
  # picture and tapped "I love it!". Confirming the candidate turns it into a
  # steppable Walkthrough and sends the child straight into it. Scoped to the
  # active Profile, so a child only ever confirms their own (ADR-0004).
  class ConfirmationsController < InertiaController
    include RequiresActiveProfile

    def create
      drawing = Current.active_profile.directed_drawings.find(params[:directed_drawing_id])
      drawing.confirm!
      redirect_to directed_drawing_path(drawing)
    end
  end
end
