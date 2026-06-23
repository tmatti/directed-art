# frozen_string_literal: true

require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "GET /dashboard redirects to the sign in page when signed out" do
    get dashboard_path
    assert_redirected_to sign_in_path
  end

  test "GET /dashboard reaches the protected page when signed in" do
    sign_in users(:one)
    get dashboard_path
    assert_response :success
  end
end
