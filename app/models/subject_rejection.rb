# frozen_string_literal: true

# A rejected Subject (ADR-0003): the verbatim free-text or transcribed-voice
# Subject the safety gate refused while a Drawing Plan was being built. Kept as a
# log so the classifier can be tuned from real data — what children actually ask
# for is the signal an off-limits list alone can't anticipate. Scoped to the
# Profile and the Plan under construction.
class SubjectRejection < ApplicationRecord
  belongs_to :profile
  belongs_to :drawing_plan

  validates :subject, presence: true
end
