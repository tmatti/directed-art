# frozen_string_literal: true

# A thin redirector that bounces signed-in users into the app: to a child's
# drawings gallery once a Profile is active, otherwise to the "who's drawing?"
# picker. sessions#create, users#create, and active_profiles#update all
# redirect here, so this keeps their targets stable.
class DashboardController < InertiaController
  include RedirectsToAppEntry

  def index
    redirect_to app_entry_path
  end
end
