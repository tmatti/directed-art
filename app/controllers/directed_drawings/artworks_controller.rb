# frozen_string_literal: true

module DirectedDrawings
  # Captures an optional photo of the child's real paper drawing at the finish
  # page and saves it as an Artwork attached to the Directed Drawing, stored via
  # Active Storage on Cloudflare R2 (ADR-0009). Scoped to the active Profile's
  # confirmed drawings, so a child only ever uploads to their own (ADR-0004) and
  # only once a drawing has cleared the confirmation gate (ADR-0002).
  class ArtworksController < InertiaController
    include RequiresActiveProfile

    def create
      drawing = Current.active_profile.directed_drawings.confirmed.find(params[:directed_drawing_id])
      drawing.artworks.create!(photo: params[:photo])
      redirect_to directed_drawing_path(drawing)
    end
  end
end
