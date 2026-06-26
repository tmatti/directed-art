# frozen_string_literal: true

class Session < ApplicationRecord
  belongs_to :user
  belongs_to :active_profile, class_name: "Profile", optional: true

  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end
end
