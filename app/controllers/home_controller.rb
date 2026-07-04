# frozen_string_literal: true

# The root route. Signed-in visitors are bounced straight into the app; signed-
# out visitors see a minimal branded landing with Log in / Sign up buttons.
class HomeController < InertiaController
  include RedirectsToAppEntry

  skip_before_action :authenticate
  before_action :perform_authentication

  def index
    redirect_to app_entry_path and return if Current.session
  end
end
