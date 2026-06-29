# frozen_string_literal: true

require "test_helper"

# Focused tests for the real RubyLLM-backed SubjectSafetyGate (ADR-0003) — the
# production adapter behind the safety seam. The live model is never called: a
# recording chat stand-in captures the request (system prompt, structured
# schema, the Subject text, model/provider) and returns a canned verdict as the
# parsed structured output, so the adapter's request mapping and response
# parsing are verified deterministically. Flow coverage stays on the fake in the
# integration suite.
class SubjectSafetyGateTest < ActiveSupport::TestCase
  # A recording chat that stands in for a RubyLLM chat: it captures the
  # instructions, schema, and ask message, and returns a canned verdict as the
  # structured-output payload.
  class RecordingChat
    attr_reader :instructions, :schema, :ask_message

    def initialize(content)
      @content = content
    end

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
      Struct.new(:content).new(@content)
    end
  end

  setup do
    @subject = "a friendly dragon"
  end

  # Inject the recording chat via the chat_builder seam, capturing the model and
  # provider the adapter chose.
  def gate_with_recording_chat(content: { "allow" => true })
    chat = RecordingChat.new(content)
    captured = {}
    gate = SubjectSafetyGate.new(
      chat_builder: ->(model:, provider:) {
        captured[:model] = model
        captured[:provider] = provider
        chat
      }
    )
    [ gate, chat, captured ]
  end

  test "maps a Subject to a RubyLLM request carrying the safety prompt, verdict schema, and lightweight model" do
    gate, chat, captured = gate_with_recording_chat
    gate.call(@subject)

    # The cheap lightweight model (ADR-0006 tiering) — not the capable generation
    # model — and the configured provider.
    assert_equal DirectedArt::LLM.lightweight_model, captured[:model]
    assert_equal DirectedArt::LLM.provider, captured[:provider]
    refute_equal DirectedArt::LLM.generation_model, captured[:model]

    # The system prompt is the production one, seeded with the over-block bias.
    assert_kind_of String, chat.instructions
    assert_match(/ages 4/i, chat.instructions)
    assert_match(/when in doubt/i, chat.instructions)

    # The structured-output schema describes a single boolean verdict.
    schema = chat.schema
    assert_kind_of Hash, schema
    assert_equal %w[allow], schema.dig(:schema, :required)
    assert_equal "boolean", schema.dig(:schema, :properties, :allow, :type)

    # The user message is the Subject text exactly as the child entered it.
    assert_equal @subject, chat.ask_message
  end

  test "returns an allow verdict when the model allows the Subject" do
    gate, = gate_with_recording_chat(content: { "allow" => true, "reason" => "kid-friendly" })
    assert gate.call(@subject).allowed?
  end

  test "returns a deny verdict when the model denies the Subject" do
    gate, = gate_with_recording_chat(content: { "allow" => false, "reason" => "off-limits" })
    assert gate.call(@subject).denied?
  end

  test "over-blocks when the model response is missing or unparseable" do
    # The over-block default (ADR-0003): anything other than an explicit allow is
    # a deny — a false allow is a disaster, a false deny is harmless.
    [ nil, {}, { "allow" => nil }, { "reason" => "no verdict" }, "not json" ].each do |content|
      gate, = gate_with_recording_chat(content: content)
      assert gate.call(@subject).denied?, "expected deny for #{content.inspect}"
    end
  end

  test "provider and model are configurable per instance" do
    chat = RecordingChat.new({ "allow" => true })
    captured = {}
    gate = SubjectSafetyGate.new(
      model: "claude-haiku-test", provider: :openai,
      chat_builder: ->(model:, provider:) {
        captured[:model] = model
        captured[:provider] = provider
        chat
      }
    )
    gate.call(@subject)
    assert_equal "claude-haiku-test", captured[:model]
    assert_equal :openai, captured[:provider]
  end

  test "the production prompt is loaded from the prompt file" do
    assert_equal File.read(Rails.root.join("app/prompts/subject_safety.md")),
      SubjectSafetyGate::PROMPT
  end
end
