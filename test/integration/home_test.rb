# frozen_string_literal: true

require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  test "GET / renders the landing page when signed out" do
    get root_path
    assert_response :success
  end

  test "GET / redirects to the profile picker when signed in without an active profile" do
    sign_in users(:one)
    get root_path
    assert_redirected_to active_profile_path
  end

  test "GET / redirects to the drawings gallery when an active profile is set" do
    sign_in users(:one)
    patch active_profile_path, params: { profile_id: profiles(:mia).id }
    get root_path
    assert_redirected_to directed_drawings_path
  end
end
