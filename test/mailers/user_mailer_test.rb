# frozen_string_literal: true

require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "email_verification is sent to the user with the correct subject" do
    mail = UserMailer.with(user: users(:one)).email_verification
    assert_equal [ "one@example.com" ], mail.to
    assert_equal "Verify your email", mail.subject
  end

  test "password_reset is sent to the user with the correct subject" do
    mail = UserMailer.with(user: users(:one)).password_reset
    assert_equal [ "one@example.com" ], mail.to
    assert_equal "Reset your password", mail.subject
  end
end
