# frozen_string_literal: true

# The real generation seam behind which all LLM concerns live (ADR-0006).
#
# Input is the confirmed Drawing Plan attributes (subject, action, mood,
# background, age_band); output is a structured drawing in the Primitive DSL
# (ADR-0001, ADR-0005). It asks RubyLLM for schema-conforming structured output
# using the capable generation model, seeded with the production prompt (itself
# seeded from the spike's hard-won rules). The job validates every result
# against the DSL schema itself and retries on malformed output, so a provider
# or model swap can never silently produce a broken drawing — this adapter only
# asks; `DrawingSchema` is the authority.
#
# Provider and model are configurable (ADR-0006: default Claude, swappable) via
# the constructor and env (`DirectedArt::LLM`). The cheap lightweight model
# (safety gate, chat turns) is wired in `DirectedArt::LLM` for the slices that
# need it; this generator uses the capable tier.
class DrawingGenerator
  # The production system prompt, seeded from spike/PROMPT.md and carrying the
  # spike's hard-won rules: anatomical completeness (never omit limbs) and
  # tapering parts drawn as `closed: true` curve silhouettes.
  PROMPT_PATH = Rails.root.join("app/prompts/drawing_generation.md")
  PROMPT = PROMPT_PATH.read.freeze

  # The structured-output JSON schema the model is asked to conform to. This is
  # a hint that gets well-shaped output; the app's own `DrawingSchema` is the
  # authority that rejects malformed drawings regardless of what the provider
  # returns. `additionalProperties: false` is required for OpenAI structured
  # output and accepted by Anthropic.
  SCHEMA = {
    name: "DirectedDrawing",
    schema: {
      type: "object",
      properties: {
        subject: { type: "string", description: "The thing being drawn" },
        title: { type: "string", description: "A friendly \"Let's draw …!\" title" },
        ageBand: { type: "string", enum: %w[4-6 7-10] },
        canvas: {
          type: "object",
          properties: {
            width: { type: "integer" },
            height: { type: "integer" }
          },
          required: %w[width height],
          additionalProperties: false
        },
        steps: {
          type: "array",
          description: "Ordered teaching steps; each adds only the NEW primitives for that step.",
          items: {
            type: "object",
            properties: {
              instruction: { type: "string", description: "Short kid-facing text" },
              narration: { type: "string", description: "Warm sentence read aloud" },
              primitives: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    type: { type: "string", enum: %w[circle ellipse line polyline polygon arc curve] },
                    color: { type: "string", description: "Hex color for the cover" },
                    cx: { type: "number" }, cy: { type: "number" }, r: { type: "number" },
                    rx: { type: "number" }, ry: { type: "number" }, rotate: { type: "number" },
                    x1: { type: "number" }, y1: { type: "number" },
                    x2: { type: "number" }, y2: { type: "number" },
                    start: { type: "number" }, end: { type: "number" },
                    points: {
                      type: "array",
                      items: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 }
                    },
                    closed: { type: "boolean" }
                  },
                  required: %w[type],
                  additionalProperties: false
                }
              }
            },
            required: %w[instruction narration primitives],
            additionalProperties: false
          }
        }
      },
      required: %w[subject title canvas steps],
      additionalProperties: false
    }
  }.freeze

  # Default chat factory: builds a RubyLLM chat for the given model/provider.
  # Overridable in tests to inject a recording chat without touching the live
  # gem.
  DEFAULT_CHAT_BUILDER = ->(model:, provider:) { RubyLLM.chat(model: model, provider: provider) }

  # The Profile Age Band enum keys mapped to the spike's "N-N" form, which is
  # what the prompt and schema understand.
  AGE_BAND_LABELS = { "ages_4_6" => "4-6", "ages_7_10" => "7-10" }.freeze

  class << self
    # The capable generation model (ADR-0006 tiering).
    def generation_model = DirectedArt::LLM.generation_model

    # The configured provider (ADR-0006: default Claude, swappable).
    def provider = DirectedArt::LLM.provider
  end

  # provider/model are configurable per instance (ADR-0006). `chat_builder` is
  # the seam that lets tests capture the request and stub the response without a
  # live model.
  def initialize(model: self.class.generation_model, provider: self.class.provider, chat_builder: DEFAULT_CHAT_BUILDER)
    @model = model
    @provider = provider
    @chat_builder = chat_builder
  end

  # Returns a structured-drawing hash (string keys, as RubyLLM parses from JSON)
  # for the given plan attributes. The job validates this against `DrawingSchema`
  # before persisting.
  def call(plan)
    chat = @chat_builder.call(model: @model, provider: @provider)
    chat.with_instructions(PROMPT)
      .with_schema(SCHEMA)
      .ask(prompt_for(plan))
      .content
  end

  private

  def prompt_for(plan)
    <<~MESSAGE
      Draw this directed drawing:
      - Subject: #{plan[:subject]}
      - Action: #{plan[:action]}
      - Mood: #{plan[:mood]}
      - Background: #{plan[:background]}
      - Age Band: #{age_band_label(plan[:age_band])}
    MESSAGE
  end

  def age_band_label(value)
    AGE_BAND_LABELS.fetch(value.to_s, value.to_s)
  end
end
