# frozen_string_literal: true

# Serves a Profile's Directed Drawings and renders the Walkthrough. Drawings are
# scoped to the active Profile, so a child only sees their own (ADR-0004), and to
# confirmed ones, so an unconfirmed candidate is never listed or stepped before
# it clears the confirmation gate (ADR-0002).
class DirectedDrawingsController < InertiaController
  include RequiresActiveProfile

  def index
    drawings = Current.active_profile.directed_drawings.confirmed.order(:created_at)
      .includes(:steps, artworks: { photo_attachment: :blob })

    render inertia: {
      # The gallery lists each Directed Drawing with its finished AI reference
      # (the full-color cover, rendered from the step primitives) and any
      # photographed Artwork(s), linking back to revisit or resume the
      # Walkthrough (ADR-0004).
      drawings: drawings.map { |drawing| gallery_entry(drawing) }
    }
  end

  def show
    drawing = Current.active_profile.directed_drawings.confirmed.find(params[:id])

    render inertia: {
      drawing: drawing.as_walkthrough,
      profile: Current.active_profile.as_json(only: %i[id name]),
      # The child's photographed real drawings, shown on the finish page so they
      # can admire and re-shoot their work. URLs are signed and served via
      # Active Storage (R2 in production).
      artworks: drawing.artworks.map { |artwork| artwork_payload(artwork) }
    }
  end

  private

  # The signed URL to an Artwork's photo, served via Active Storage (R2 in
  # production).
  def artwork_payload(artwork)
    { id: artwork.id, photo_url: url_for(artwork.photo) }
  end

  # A gallery entry: the finished reference (canvas + steps, enough to render
  # the cover) plus the child's photographed Artwork(s), scoped to the active
  # Profile by the query above.
  def gallery_entry(drawing)
    drawing.as_walkthrough.merge(
      artworks: drawing.artworks.map { |artwork| artwork_payload(artwork) }
    )
  end
end
