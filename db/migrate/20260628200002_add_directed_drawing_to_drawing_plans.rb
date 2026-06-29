# frozen_string_literal: true

# Links a Drawing Plan to the Directed Drawing its generation produced. Null
# until the background job finishes (ADR-0009); the Plan's status enum carries
# the pending/ready/failed lifecycle the wait screen polls.
class AddDirectedDrawingToDrawingPlans < ActiveRecord::Migration[8.1]
  def change
    add_reference :drawing_plans, :directed_drawing, foreign_key: { on_delete: :nullify }
  end
end
