# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module SignInHelper
  def sign_in(user)
    session = user.sessions.create!
    cookies[:session_token] = signed_cookie(:session_token, session.id)
  end

  def sign_out
    cookies[:session_token] = ""
  end

  private

  def signed_cookie(name, value)
    cookie_jar = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    cookie_jar.signed[name] = value
    cookie_jar[name]
  end
end

module ActiveSupport
  class TestCase
    # Inertia responses trigger a Vite build into a shared directory, so running
    # tests in parallel would race on that output. Keep the suite serial.
    fixtures :all
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
  include ActionMailer::TestHelper
end
