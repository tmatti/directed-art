# frozen_string_literal: true

class Profile < ApplicationRecord
  # Coarse age groupings (Age Band) that drive a Directed Drawing's complexity.
  AGE_BANDS = { ages_4_6: 0, ages_7_10: 1 }.freeze

  belongs_to :user
  has_many :directed_drawings, dependent: :destroy

  enum :age_band, AGE_BANDS, validate: true

  validates :name, presence: true
end
