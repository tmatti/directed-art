require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DirectedArt
  # Model tiering and provider wiring for the RubyLLM seam (ADR-0006).
  #
  # All LLM calls go through RubyLLM rather than a single provider SDK, so the
  # provider/model is a configuration choice, not an architectural commitment.
  # The default provider is Claude (Anthropic); swap it via env without touching
  # the generators that depend on these names.
  #
  # We tier models for cost (ADR-0006): a capable model for drawing generation,
  # and a cheap, fast model for the safety classification gate and lightweight
  # chat turns. The generation generator consumes `generation_model`; the
  # lightweight model is wired here so the safety slice can pick it up without
  # re-deciding the tier. Defined before the Application class so initializers
  # (and models) can reference it at boot.
  module LLM
    # The provider behind every call: `:anthropic`, `:openai`, etc. — any
    # RubyLLM provider. Default Claude, per ADR-0006.
    PROVIDER = ENV.fetch("DIRECTED_ART_LLM_PROVIDER", "anthropic").to_sym

    # The capable model that produces a structured drawing from a Plan. Drawing
    # generation is the demanding call, so it gets the stronger model.
    GENERATION_MODEL = ENV.fetch("DIRECTED_ART_GENERATION_MODEL", "claude-sonnet-4-5")

    # The cheap, fast model for lightweight calls: the safety classification
    # gate on free-text Subjects and the guided-chat turns. Wired here so the
    # safety slice can use it without re-deciding the tier.
    LIGHTWEIGHT_MODEL = ENV.fetch("DIRECTED_ART_LIGHTWEIGHT_MODEL", "claude-haiku-4-5")

    class << self
      def provider = PROVIDER
      def generation_model = GENERATION_MODEL
      def lightweight_model = LIGHTWEIGHT_MODEL
    end
  end

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
