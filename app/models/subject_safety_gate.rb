# frozen_string_literal: true

# The Subject safety gate (ADR-0003): the second safety layer, sitting between
# the curated suggestion chips (safe by construction) and constrained generation
# (the backstop). Any free-text or transcribed-voice **Subject** is classified
# here before it's accepted into a Drawing Plan. Off-limits Subjects are gently
# redirected, not errored.
#
# This is the same fakeable-LLM seam pattern as `DrawingGenerator`: a thin
# adapter behind which all model concerns live, injected via
# `DrawingPlan.subject_safety_gate` and faked in tests. It uses the **cheap
# lightweight model** (ADR-0006 tiering) — a single classification call, not a
# generation. Bias is toward over-blocking: a false "let's pick something else"
# is harmless, a false allow is a disaster. That bias is enforced both in the
# prompt and in `parse_verdict`, which denies unless the model explicitly allows.
class SubjectSafetyGate
  # The verdict the gate returns. `allow` only when the classifier explicitly
  # says so; everything else (a deny, an unparseable response, an error) is a
  # deny — the over-block default.
  Verdict = Data.define(:allowed) do
    def allowed? = allowed
    def denied? = !allowed
    def self.allow = new(true)
    def self.deny = new(false)
  end

  # The production system prompt: a strong age-4–10 Subject classifier biased
  # toward over-blocking. Seeded from `app/prompts/subject_safety.md`.
  PROMPT_PATH = Rails.root.join("app/prompts/subject_safety.md")
  PROMPT = PROMPT_PATH.read.freeze

  # The structured-output JSON schema the model is asked to conform to: a single
  # boolean verdict. `additionalProperties: false` is required for OpenAI
  # structured output and accepted by Anthropic. The app parses the response
  # defensively (over-block on anything other than an explicit allow), so this
  # schema is a hint, not the authority.
  SCHEMA = {
    name: "SubjectSafetyVerdict",
    schema: {
      type: "object",
      properties: {
        allow: { type: "boolean", description: "true only if the subject is appropriate for ages 4-10" },
        reason: { type: "string", description: "a brief reason for the decision" }
      },
      required: %w[allow],
      additionalProperties: false
    }
  }.freeze

  # Default chat factory: builds a RubyLLM chat for the given model/provider.
  # Overridable in tests to inject a recording chat without touching the live
  # gem.
  DEFAULT_CHAT_BUILDER = ->(model:, provider:) { RubyLLM.chat(model: model, provider: provider) }

  class << self
    # The cheap lightweight model (ADR-0006 tiering) — not the capable generation
    # model, which a classification call doesn't need.
    def lightweight_model = DirectedArt::LLM.lightweight_model

    # The configured provider (ADR-0006: default OpenRouter, swappable).
    def provider = DirectedArt::LLM.provider
  end

  # provider/model are configurable per instance (ADR-0006). `chat_builder` is
  # the seam that lets tests capture the request and stub the response without a
  # live model.
  def initialize(model: self.class.lightweight_model, provider: self.class.provider, chat_builder: DEFAULT_CHAT_BUILDER)
    @model = model
    @provider = provider
    @chat_builder = chat_builder
  end

  # Classify a free-text or transcribed-voice Subject. Returns a Verdict; the
  # caller redirects (never errors) on a deny.
  def call(subject)
    chat = @chat_builder.call(model: @model, provider: @provider)
    response = chat.with_instructions(PROMPT).with_schema(SCHEMA).ask(subject)
    parse_verdict(response.content)
  end

  private

  # Over-block (ADR-0003): allow only on an explicit `true`; deny on false, a
  # missing key, a non-hash response, or anything else. A false allow is a
  # disaster; a false deny is harmless.
  def parse_verdict(content)
    content.is_a?(Hash) && content["allow"] == true ? Verdict.allow : Verdict.deny
  end
end
