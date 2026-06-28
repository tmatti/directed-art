# frozen_string_literal: true

class CreateDrawingPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :drawing_plans do |t|
      t.references :profile, null: false, foreign_key: true
      # The Plan attributes the guided chat fills, one slot per question. Only
      # the Subject is required; the rest default sensibly when skipped.
      t.string :subject
      t.string :action
      t.string :mood
      t.string :background
      # Derived from the Profile's Age Band (ADR-0003), never asked of the child.
      t.integer :age_band, null: false
      # 0 = building (mid-conversation), 1 = completed (every slot filled).
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
