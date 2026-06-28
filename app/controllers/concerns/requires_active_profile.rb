# frozen_string_literal: true

# Guards actions that act on the active Profile's data, sending a child to the
# "who's drawing?" picker when no Profile has been chosen yet.
module RequiresActiveProfile
  extend ActiveSupport::Concern

  included do
    before_action :require_active_profile
  end

  private

  def require_active_profile
    redirect_to active_profile_path unless Current.active_profile
  end
end
