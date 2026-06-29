# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "inertia_rails/minitest"

# The faked generation seam (ADR-0006): tests drive the async pipeline with a
# canned spike drawing instead of a live model. Required before the test default
# below is wired.
require_relative "support/fake_drawing_generator"

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

# The generation seam defaults to the real RubyLLM-backed DrawingGenerator in
# production; tests inject the fake so every flow runs without a live model
# (ADR-0006). Individual tests may swap in their own stub and restore this in
# teardown.
GenerateDirectedDrawingJob.generator = FakeDrawingGenerator.new

class ActionDispatch::IntegrationTest
  include SignInHelper
  include ActionMailer::TestHelper
end
