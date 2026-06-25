# frozen_string_literal: true

require "test_helper"

class ProfilesTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "GET /profiles redirects to sign in when signed out" do
    sign_out
    get profiles_path
    assert_redirected_to sign_in_path
  end

  test "GET /profiles lists the account's profiles" do
    get profiles_path
    assert_response :success
  end

  test "GET /profiles/new renders the form" do
    get new_profile_path
    assert_response :success
  end

  test "POST /profiles creates a profile for the current account" do
    assert_difference -> { users(:one).profiles.count }, 1 do
      post profiles_path, params: { name: "Ada", age_band: "ages_7_10" }
    end
    assert_redirected_to profiles_path
    profile = users(:one).profiles.order(:created_at).last
    assert_equal "Ada", profile.name
    assert_equal "ages_7_10", profile.age_band
  end

  test "POST /profiles with a blank name returns inertia errors" do
    assert_no_difference -> { Profile.count } do
      post profiles_path, params: { name: "", age_band: "ages_4_6" }
    end
    assert_redirected_to new_profile_path
    assert session[:inertia_errors][:name].present?
  end

  test "GET /profiles/:id/edit renders the form for an owned profile" do
    get edit_profile_path(profiles(:mia))
    assert_response :success
  end

  test "PATCH /profiles/:id updates an owned profile" do
    patch profile_path(profiles(:mia)), params: { name: "Mia B.", age_band: "ages_7_10" }
    assert_redirected_to profiles_path
    assert_equal "Mia B.", profiles(:mia).reload.name
    assert_equal "ages_7_10", profiles(:mia).reload.age_band
  end

  test "DELETE /profiles/:id removes an owned profile" do
    assert_difference -> { Profile.count }, -1 do
      delete profile_path(profiles(:mia))
    end
    assert_redirected_to profiles_path
  end

  test "deleting the active profile clears it from the session" do
    session = users(:one).sessions.last
    patch active_profile_path, params: { profile_id: profiles(:mia).id }
    assert_equal profiles(:mia).id, session.reload.active_profile_id

    delete profile_path(profiles(:mia))
    assert_nil session.reload.active_profile_id
  end

  # --- Authorization / account scoping (ADR-0004) ---

  test "cannot edit another account's profile" do
    get edit_profile_path(profiles(:other_kid))
    assert_response :not_found
  end

  test "cannot update another account's profile" do
    patch profile_path(profiles(:other_kid)), params: { name: "Hacked" }
    assert_response :not_found
    assert_equal "Sam", profiles(:other_kid).reload.name
  end

  test "cannot delete another account's profile" do
    assert_no_difference -> { Profile.count } do
      delete profile_path(profiles(:other_kid))
    end
    assert_response :not_found
  end
end
