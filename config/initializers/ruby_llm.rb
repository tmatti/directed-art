# frozen_string_literal: true

# RubyLLM — the one LLM seam behind DrawingGenerator (ADR-0006). Default
# provider OpenRouter, which proxies Claude (and the other vendors) behind a
# single key; swappable via DIRECTED_ART_LLM_PROVIDER. The key comes from Rails
# credentials first, with OPENROUTER_API_KEY as an env fallback for local dev
# and CI. The gem stays quiet about any provider whose key is unset, as long as
# nothing calls it.
RubyLLM.configure do |config|
  config.openrouter_api_key = Rails.application.credentials.dig(:openrouter, :api_key) || ENV["OPENROUTER_API_KEY"]

  # Model tiering (ADR-0006): the capable model is the default for chat, so a
  # bare `RubyLLM.chat` matches the generation tier. Lightweight callers
  # (safety gate, chat turns) opt into the cheap model explicitly.
  config.default_model = DirectedArt::LLM.generation_model

  config.logger    = Rails.logger
  config.log_level = Rails.env.production? ? :info : :debug
end
