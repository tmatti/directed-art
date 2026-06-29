# frozen_string_literal: true

# A photo of a child's actual physical drawing (crayon/pencil/paint on paper)
# saved to their gallery, distinct from the AI's rendered reference. A Directed
# Drawing can collect many Artworks, because a child may repeat the steps and
# upload a new photo each time. Stored via Active Storage on Cloudflare R2
# (ADR-0009).
class Artwork < ApplicationRecord
  belongs_to :directed_drawing

  has_one_attached :photo
end
