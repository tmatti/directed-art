# frozen_string_literal: true

# The rejected-Subjects log (ADR-0003): every free-text or transcribed-voice
# Subject the safety gate refuses is recorded here so the gate can be tuned from
# real data. Scoped to the Profile (and the Plan that was being built) so
# rejections can be aggregated per child or across the app.
class CreateSubjectRejection < ActiveRecord::Migration[8.1]
  def change
    create_table :subject_rejections do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :drawing_plan, null: false, foreign_key: true
      # The Subject text the child typed or spoke, exactly as received before the
      # gate refused it. Kept verbatim for tuning the classifier.
      t.text :subject, null: false

      t.timestamps
    end
  end
end
