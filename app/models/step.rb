# frozen_string_literal: true

# One stage of a Directed Drawing. Carries the instruction the child follows and
# the new Primitives this Step appends to the cumulative drawing (ADR-0001).
class Step < ApplicationRecord
  belongs_to :directed_drawing

  validates :position, presence: true, uniqueness: { scope: :directed_drawing_id }
  validates :instruction, presence: true
end
