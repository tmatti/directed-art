# frozen_string_literal: true

require "test_helper"

class Settings::EmailsTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "GET /settings/email renders the email settings page" do
    get settings_email_path
    assert_response :success
  end

  test "PATCH /settings/email with valid challenge updates the email" do
    patch settings_email_path, params: {
      email: "updated@example.com",
      password_challenge: "Secret1*3*5*"
    }
    assert_redirected_to settings_email_path
    assert_equal "Your email has been changed", flash[:notice]
    assert_equal "updated@example.com", users(:one).reload.email
  end

  test "PATCH /settings/email with invalid challenge returns inertia errors" do
    patch settings_email_path, params: {
      email: "updated@example.com",
      password_challenge: "wrongpassword"
    }
    assert_redirected_to settings_email_path
    assert_equal({ password_challenge: [ "is invalid" ] }, session[:inertia_errors])
    assert_equal "one@example.com", users(:one).reload.email
  end
end
