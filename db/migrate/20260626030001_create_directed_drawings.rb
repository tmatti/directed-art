# frozen_string_literal: true

class CreateDirectedDrawings < ActiveRecord::Migration[8.1]
  def change
    create_table :directed_drawings do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :subject, null: false
      t.string :title, null: false
      t.integer :age_band, null: false
      t.integer :canvas_width, null: false, default: 600
      t.integer :canvas_height, null: false, default: 600
      # The resumable page index of the Walkthrough: 0 = cover, 1..N = Steps,
      # N+1 = the finish page. A child returns to where they left off.
      t.integer :current_step, null: false, default: 0

      t.timestamps
    end
  end
end
