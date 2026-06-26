# frozen_string_literal: true

# The "who's drawing today?" picker. Stores the chosen Profile on the current
# Session, so the choice persists for the life of the signed-in session.
class ActiveProfilesController < InertiaController
  def show
    render inertia: {
      profiles: Current.user.profiles.order(:name).as_json(only: %i[id name age_band])
    }
  end

  def update
    profile = Current.user.profiles.find(params[:profile_id])
    Current.session.update!(active_profile: profile)
    redirect_to dashboard_path, notice: "#{profile.name} is drawing today"
  end
end
