# frozen_string_literal: true

require "test_helper"

class ActiveProfilesTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "GET /active_profile renders the picker" do
    get active_profile_path
    assert_response :success
  end

  test "PATCH /active_profile sets the active profile on the session" do
    session = users(:one).sessions.last
    patch active_profile_path, params: { profile_id: profiles(:mia).id }
    assert_redirected_to dashboard_path
    assert_equal profiles(:mia).id, session.reload.active_profile_id
  end

  test "the active profile persists across requests in the same session" do
    patch active_profile_path, params: { profile_id: profiles(:leo).id }
    get dashboard_path
    assert_redirected_to directed_drawings_path
    assert_equal profiles(:leo).id, users(:one).sessions.last.reload.active_profile_id
  end

  test "cannot select another account's profile" do
    patch active_profile_path, params: { profile_id: profiles(:other_kid).id }
    assert_response :not_found
    assert_nil users(:one).sessions.last.reload.active_profile_id
  end

  test "requires authentication" do
    sign_out
    get active_profile_path
    assert_redirected_to sign_in_path
  end
end
