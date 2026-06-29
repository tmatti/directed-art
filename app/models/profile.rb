# frozen_string_literal: true

class Profile < ApplicationRecord
  # Coarse age groupings (Age Band) that drive a Directed Drawing's complexity.
  AGE_BANDS = { ages_4_6: 0, ages_7_10: 1 }.freeze

  belongs_to :user
  has_many :directed_drawings, dependent: :destroy
  has_many :drawing_plans, dependent: :destroy
  # Subjects the safety gate refused for this child (ADR-0003), logged per
  # Profile so rejections can be aggregated per child or across the app.
  has_many :subject_rejections, dependent: :destroy

  enum :age_band, AGE_BANDS, validate: true

  validates :name, presence: true
end
