# frozen_string_literal: true

class CreateSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :steps do |t|
      # The composite unique index below covers directed_drawing_id as a prefix,
      # so skip the standalone index t.references would otherwise add.
      t.references :directed_drawing, null: false, foreign_key: true, index: false
      t.integer :position, null: false
      t.text :instruction, null: false
      t.text :narration
      # The new Primitives this Step adds, in the constrained DSL (ADR-0001).
      t.jsonb :primitives, null: false, default: []

      t.timestamps
    end

    add_index :steps, [ :directed_drawing_id, :position ], unique: true
  end
end
