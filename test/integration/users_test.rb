# frozen_string_literal: true

require "test_helper"

class UsersTest < ActionDispatch::IntegrationTest
  test "GET /sign_up renders the sign up page" do
    get sign_up_path
    assert_response :success
  end

  test "GET /sign_up redirects authenticated users" do
    sign_in users(:one)
    get sign_up_path
    assert_redirected_to root_path
  end

  test "POST /sign_up creates a new user" do
    assert_difference("User.count", 1) do
      post sign_up_path, params: {
        name: "New User",
        email: "new@example.com",
        password: "Secret1*3*5*",
        password_confirmation: "Secret1*3*5*"
      }
    end
    assert_redirected_to dashboard_path
  end

  test "POST /sign_up rejects an invalid user" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        name: "",
        email: "invalid",
        password: "short",
        password_confirmation: "short"
      }
    end
    assert_redirected_to sign_up_path
  end

  test "DELETE /users destroys current user with valid password" do
    sign_in users(:one)
    assert_difference("User.count", -1) do
      delete users_path, params: { password_challenge: "Secret1*3*5*" }
    end
    assert_redirected_to root_path
  end

  test "DELETE /users rejects account deletion with wrong password" do
    sign_in users(:one)
    assert_no_difference("User.count") do
      delete users_path, params: { password_challenge: "wrongpassword" }
    end
    assert_redirected_to settings_profile_path
  end
end
