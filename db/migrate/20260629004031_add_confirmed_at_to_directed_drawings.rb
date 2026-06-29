# frozen_string_literal: true

# When the child confirmed the finished-picture preview (ADR-0002). Null while a
# generated candidate still awaits the confirmation gate; only a confirmed
# Directed Drawing is a steppable Walkthrough.
class AddConfirmedAtToDirectedDrawings < ActiveRecord::Migration[8.1]
  def change
    add_column :directed_drawings, :confirmed_at, :datetime
  end
end
