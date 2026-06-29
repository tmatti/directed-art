# frozen_string_literal: true

class CreateArtwork < ActiveRecord::Migration[8.1]
  def change
    create_table :artworks do |t|
      t.references :directed_drawing, null: false, foreign_key: true

      t.timestamps
    end
  end
end
