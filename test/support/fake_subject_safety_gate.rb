# frozen_string_literal: true

# The faked `SubjectSafetyGate` (ADR-0003): returns a canned allow/deny verdict
# and records the last Subject it was asked about, so request-level tests drive
# the safety flow with zero model risk. The real RubyLLM-backed gate is the
# production default; this fake is the test default, wired in `test_helper.rb`.
# Individual tests swap in their own instance (configured to allow or deny) and
# inspect `last_subject` to prove the gate was or wasn't called.
class FakeSubjectSafetyGate
  attr_reader :last_subject

  # `allow:` configures the verdict this fake returns (defaults to allow, so the
  # existing chat flows run untouched when the suite default is wired).
  def initialize(allow: true)
    @allow = allow
  end

  def call(subject)
    @last_subject = subject
    @allow ? SubjectSafetyGate::Verdict.allow : SubjectSafetyGate::Verdict.deny
  end
end
