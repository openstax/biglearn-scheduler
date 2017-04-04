class CreateClueCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :clue_calculations do |t|
      t.uuid  :uuid,           null: false, index: { unique: true }
      t.uuid  :ecosystem_uuid, null: false, index: true
      t.uuid  :exercise_uuids, null: false, array: true
      t.uuid  :student_uuids,  null: false, array: true

      t.timestamps             null: false
    end
  end
end
