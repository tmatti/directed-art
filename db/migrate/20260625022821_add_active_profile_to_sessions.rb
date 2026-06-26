# frozen_string_literal: true

class AddActiveProfileToSessions < ActiveRecord::Migration[8.1]
  def change
    add_reference :sessions, :active_profile, null: true,
                  foreign_key: { to_table: :profiles, on_delete: :nullify }
  end
end
