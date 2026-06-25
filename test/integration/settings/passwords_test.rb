# frozen_string_literal: true

require "test_helper"

class Settings::PasswordsTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "GET /settings/password renders the password settings page" do
    get settings_password_path
    assert_response :success
  end

  test "PATCH /settings/password with valid challenge updates the password" do
    patch settings_password_path, params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*",
      password_challenge: "Secret1*3*5*"
    }
    assert_redirected_to settings_password_path
    assert_equal "Your password has been changed", flash[:notice]
  end

  test "PATCH /settings/password with invalid challenge returns inertia errors" do
    patch settings_password_path, params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*",
      password_challenge: "wrongpassword"
    }
    assert_redirected_to settings_password_path
    assert_equal({ password_challenge: [ "is invalid" ] }, session[:inertia_errors])
  end
end
