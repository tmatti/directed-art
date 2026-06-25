# frozen_string_literal: true

require "test_helper"

class Settings::SessionsTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "GET /settings/sessions renders the sessions index" do
    get settings_sessions_path
    assert_response :success
  end
end
