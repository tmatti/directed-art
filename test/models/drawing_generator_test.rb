# frozen_string_literal: true

require "test_helper"

# Focused tests for the real RubyLLM-backed DrawingGenerator (ADR-0006) — the
# production adapter behind the generation seam. The live model is never called:
# a recording chat stand-in captures the request (system prompt, structured
# schema, user message, model/provider) and returns a canned valid drawing as
# the parsed structured output, so the adapter's request mapping and response
# parsing are verified deterministically. Flow coverage stays on the fake in the
# job and integration suites.
class DrawingGeneratorTest < ActiveSupport::TestCase
  # A recording chat that stands in for a RubyLLM chat: it captures the
  # instructions, schema, and ask message, and returns a canned valid drawing
  # as the structured-output payload.
  class RecordingChat
    attr_reader :instructions, :schema, :ask_message

    def with_instructions(prompt)
      @instructions = prompt
      self
    end

    def with_schema(schema)
      @schema = schema
      self
    end

    def ask(message)
      @ask_message = message
      Struct.new(:content).new(JSON.parse(CANNED_VALID_DRAWING_JSON))
    end
  end

  CANNED_VALID_DRAWING_JSON = Rails.root.join("db/seed_drawings/happy_sun.json").read

  setup do
    @plan = {
      subject: "a dragon",
      action: "flying",
      mood: "silly",
      background: "the sky",
      # The enum key the Plan hands across the seam (DrawingPlan#age_band).
      age_band: "ages_7_10"
    }
  end

  # Inject the recording chat via the chat_builder seam, capturing the model and
  # provider the adapter chose.
  def generator_with_recording_chat
    chat = RecordingChat.new
    captured = {}
    generator = DrawingGenerator.new(
      chat_builder: ->(model:, provider:) {
        captured[:model] = model
        captured[:provider] = provider
        chat
      }
    )
    [ generator, chat, captured ]
  end

  test "maps a Plan to a RubyLLM request carrying the production prompt, DSL schema, and generation model" do
    generator, chat, captured = generator_with_recording_chat
    drawing = generator.call(@plan)

    # The chat is built with the capable generation model and configured provider.
    assert_equal DirectedArt::LLM.generation_model, captured[:model]
    assert_equal DirectedArt::LLM.provider, captured[:provider]

    # The system prompt is the production one, seeded with the spike's hard-won
    # rules: anatomical completeness (never omit limbs) and closed-curve
    # silhouettes for tapering parts.
    assert_kind_of String, chat.instructions
    assert_match(/anatomically/i, chat.instructions)
    assert_match(/never omit/i, chat.instructions)
    assert_match(/closed: true/i, chat.instructions)
    assert_match(/taper/i, chat.instructions)

    # The structured-output schema describes the Primitive DSL: the fixed
    # primitive type enum and the step canvas/instruction/narration shape.
    schema = chat.schema
    assert_kind_of Hash, schema
    type_enum = schema.dig(:schema, :properties, :steps, :items, :properties, :primitives, :items, :properties, :type, :enum)
    assert_equal %w[circle ellipse line polyline polygon arc curve], type_enum
    required = schema.dig(:schema, :required)
    assert_includes required, "subject"
    assert_includes required, "steps"

    # The user message carries every Plan attribute, with the Age Band
    # translated to the spike's "N-N" form (never the raw enum key).
    assert_match(/a dragon/, chat.ask_message)
    assert_match(/flying/, chat.ask_message)
    assert_match(/silly/, chat.ask_message)
    assert_match(/the sky/, chat.ask_message)
    assert_match(/7-10/, chat.ask_message)
    refute_match(/ages_7_10/, chat.ask_message)

    # The response content is returned as the structured drawing and is valid
    # against the app's own DSL validator — the authority, per ADR-0006.
    assert_equal "a happy sun", drawing["subject"]
    assert_empty DrawingSchema.validate(drawing)
  end

  test "provider and model are configurable per instance" do
    chat = RecordingChat.new
    captured = {}
    generator = DrawingGenerator.new(
      model: "claude-opus-4-1", provider: :openai,
      chat_builder: ->(model:, provider:) {
        captured[:model] = model
        captured[:provider] = provider
        chat
      }
    )
    generator.call(@plan)
    assert_equal "claude-opus-4-1", captured[:model]
    assert_equal :openai, captured[:provider]
  end

  test "model tiering: a cheap lightweight model is wired and distinct from the capable generation model" do
    assert DirectedArt::LLM.lightweight_model.present?
    refute_equal DirectedArt::LLM.generation_model, DirectedArt::LLM.lightweight_model
  end

  test "the production prompt is loaded from the prompt file" do
    assert_equal File.read(Rails.root.join("app/prompts/drawing_generation.md")),
      DrawingGenerator::PROMPT
  end
end
