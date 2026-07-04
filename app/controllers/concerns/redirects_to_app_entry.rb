# frozen_string_literal: true

# Resolves the post-login landing place: a child's drawings gallery once a
# Profile is active, otherwise the "who's drawing?" picker. Used by the
# dashboard and home actions to bounce signed-in users straight into the app
# instead of showing a placeholder page.
module RedirectsToAppEntry
  extend ActiveSupport::Concern

  private

  def app_entry_path
    if Current.active_profile
      directed_drawings_path
    else
      active_profile_path
    end
  end
end
