# frozen_string_literal: true

# RubyLLM — the one LLM seam behind DrawingGenerator (ADR-0006). Default
# provider Claude (Anthropic); swappable via DIRECTED_ART_LLM_PROVIDER. API keys
# come from env or Rails credentials; the gem stays quiet about any provider
# whose key is unset, as long as nothing calls it.
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"] || Rails.application.credentials.dig(:anthropic, :api_key)
  config.openai_api_key    = ENV["OPENAI_API_KEY"]    || Rails.application.credentials.dig(:openai, :api_key)

  # Model tiering (ADR-0006): the capable model is the default for chat, so a
  # bare `RubyLLM.chat` matches the generation tier. Lightweight callers
  # (safety gate, chat turns) opt into the cheap model explicitly.
  config.default_model = DirectedArt::LLM.generation_model

  config.logger    = Rails.logger
  config.log_level = Rails.env.production? ? :info : :debug
end
