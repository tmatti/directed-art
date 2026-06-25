# frozen_string_literal: true

class ProfilesController < InertiaController
  before_action :set_profile, only: %i[edit update destroy]

  def index
    render inertia: { profiles: serialize(Current.user.profiles.order(:name)) }
  end

  def new
  end

  def create
    profile = Current.user.profiles.new(profile_params)

    if profile.save
      redirect_to profiles_path, notice: "#{profile.name}'s profile has been created"
    else
      redirect_to new_profile_path, inertia: { errors: profile.errors }
    end
  end

  def edit
    render inertia: { profile: serialize(@profile) }
  end

  def update
    if @profile.update(profile_params)
      redirect_to profiles_path, notice: "#{@profile.name}'s profile has been updated"
    else
      redirect_to edit_profile_path(@profile), inertia: { errors: @profile.errors }
    end
  end

  def destroy
    @profile.destroy
    redirect_to profiles_path, notice: "#{@profile.name}'s profile has been deleted"
  end

  private

  def set_profile
    @profile = Current.user.profiles.find(params[:id])
  end

  def profile_params
    params.permit(:name, :age_band)
  end

  def serialize(profiles)
    profiles.as_json(only: %i[id name age_band])
  end
end
