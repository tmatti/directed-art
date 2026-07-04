# frozen_string_literal: true

require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "GET /dashboard redirects to the sign in page when signed out" do
    get dashboard_path
    assert_redirected_to sign_in_path
  end

  test "GET /dashboard redirects to the profile picker when signed in without an active profile" do
    sign_in users(:one)
    get dashboard_path
    assert_redirected_to active_profile_path
  end

  test "GET /dashboard redirects to the drawings gallery when an active profile is set" do
    sign_in users(:one)
    patch active_profile_path, params: { profile_id: profiles(:mia).id }
    get dashboard_path
    assert_redirected_to directed_drawings_path
  end
end
