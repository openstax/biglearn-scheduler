class CreateResponses < ActiveRecord::Migration[5.0]
  def change
    create_table :responses do |t|
      t.uuid     :uuid,          null: false, index: { unique: true }
      t.uuid     :trial_uuid,    null: false, index: true
      t.uuid     :student_uuid,  null: false, index: true
      t.uuid     :exercise_uuid, null: false, index: true
      t.datetime :responded_at,  null: false, index: true
      t.boolean  :is_correct,    null: false

      t.timestamps               null: false
    end
  end
end
