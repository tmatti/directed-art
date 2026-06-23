# frozen_string_literal: true

require "test_helper"

class Identity::PasswordResetsTest < ActionDispatch::IntegrationTest
  test "GET new renders the forgot password page" do
    get new_identity_password_reset_path
    assert_response :success
  end

  test "POST with a verified user sends a password reset email" do
    assert_enqueued_emails 1 do
      post identity_password_reset_path, params: { email: users(:one).email }
    end
    assert_redirected_to sign_in_path
  end

  test "POST with an unverified user does not send a password reset email" do
    users(:one).update!(verified: false)

    assert_no_enqueued_emails do
      post identity_password_reset_path, params: { email: users(:one).email }
    end
    assert_redirected_to new_identity_password_reset_path
    assert_equal "You can't reset your password until you verify your email", flash[:alert]
  end

  test "POST with a nonexistent email does not send a password reset email" do
    assert_no_enqueued_emails do
      post identity_password_reset_path, params: { email: "missing@example.com" }
    end
    assert_redirected_to new_identity_password_reset_path
  end

  test "GET edit renders the reset page with a valid token" do
    sid = users(:one).generate_token_for(:password_reset)
    get edit_identity_password_reset_path(sid: sid)
    assert_response :success
  end

  test "GET edit rejects an invalid reset token" do
    get edit_identity_password_reset_path(sid: "invalid")
    assert_redirected_to new_identity_password_reset_path
  end

  test "PATCH with a valid token updates the password" do
    sid = users(:one).generate_token_for(:password_reset)
    patch identity_password_reset_path(sid: sid), params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*"
    }
    assert_redirected_to sign_in_path
  end

  test "PATCH with an expired token rejects the password change" do
    sid = users(:one).generate_token_for(:password_reset)
    travel 30.minutes

    patch identity_password_reset_path(sid: sid), params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*"
    }
    assert_redirected_to new_identity_password_reset_path
    assert_equal "That password reset link is invalid", flash[:alert]
  end

  test "PATCH with a mismatched confirmation rejects the password change" do
    sid = users(:one).generate_token_for(:password_reset)
    patch identity_password_reset_path(sid: sid), params: {
      password: "NewPassword1*3*",
      password_confirmation: "different"
    }
    assert_redirected_to edit_identity_password_reset_path(sid: sid)
  end
end
