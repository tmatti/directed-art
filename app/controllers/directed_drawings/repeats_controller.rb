# frozen_string_literal: true

module DirectedDrawings
  # Repeat an existing, confirmed Directed Drawing (ADR-0008): the child re-walks
  # its Steps from the start, so they can finish and upload another Artwork — one
  # DirectedDrawing collects many Artworks over time. Scoped to the active
  # Profile's confirmed drawings, so a child only ever repeats their own
  # (ADR-0004) and only one that has cleared the confirmation gate (ADR-0002).
  class RepeatsController < InertiaController
    include RequiresActiveProfile

    def create
      drawing = Current.active_profile.directed_drawings.confirmed.find(params[:directed_drawing_id])
      drawing.repeat!
      redirect_to directed_drawing_path(drawing)
    end
  end
end
