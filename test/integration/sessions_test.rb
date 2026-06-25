# frozen_string_literal: true

require "test_helper"

class SessionsTest < ActionDispatch::IntegrationTest
  test "GET /sign_in renders the sign in page" do
    get sign_in_path
    assert_response :success
  end

  test "GET /sign_in redirects authenticated users" do
    sign_in users(:one)
    get sign_in_path
    assert_redirected_to root_path
  end

  test "POST /sign_in with valid credentials signs in and sets a session cookie" do
    post sign_in_path, params: { email: users(:one).email, password: "Secret1*3*5*" }
    assert_redirected_to dashboard_path
    assert cookies[:session_token].present?
  end

  test "POST /sign_in with invalid credentials redirects back with an alert" do
    post sign_in_path, params: { email: users(:one).email, password: "wrongpassword" }
    assert_redirected_to sign_in_path
    assert_equal "That email or password is incorrect", flash[:alert]
  end

  test "DELETE /sessions/:id destroys the session" do
    sign_in users(:one)
    session_record = users(:one).sessions.last
    delete session_path(session_record)
    assert_redirected_to settings_sessions_path
  end
end
