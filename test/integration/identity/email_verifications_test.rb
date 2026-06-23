# frozen_string_literal: true

require "test_helper"

class Identity::EmailVerificationsTest < ActionDispatch::IntegrationTest
  test "GET with a valid token verifies the email" do
    user = users(:one)
    user.update!(verified: false)
    sid = user.generate_token_for(:email_verification)

    get identity_email_verification_path(sid: sid)
    assert_redirected_to root_path
    assert user.reload.verified?
  end

  test "GET with an expired token does not verify the email" do
    user = users(:one)
    user.update!(verified: false)
    sid = user.generate_token_for(:email_verification)

    travel 3.days

    get identity_email_verification_path(sid: sid)
    assert_redirected_to settings_email_path
    assert_equal "That email verification link is invalid", flash[:alert]
    assert_not user.reload.verified?
  end

  test "GET with an invalid token redirects to settings email" do
    get identity_email_verification_path(sid: "invalid")
    assert_redirected_to settings_email_path
  end

  test "POST resends the verification email" do
    sign_in users(:one)

    assert_enqueued_emails 1 do
      post identity_email_verification_path
    end
    assert_response :redirect
  end
end
