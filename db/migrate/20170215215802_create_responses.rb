class CreateResponses < ActiveRecord::Migration[5.0]
  def change
    create_table :responses do |t|
      t.uuid     :uuid,                             null: false, index: { unique: true }
      t.uuid     :ecosystem_uuid,                   null: false, index: true
      t.uuid     :trial_uuid,                       null: false, index: true
      t.uuid     :student_uuid,                     null: false, index: true
      t.uuid     :exercise_uuid,                    null: false
      t.datetime :responded_at,                     null: false, index: true
      t.boolean  :is_correct,                       null: false
      t.boolean  :used_in_clue_calculations,        null: false, index: true
      t.boolean  :used_in_exercise_calculations,    null: false, index: true
      t.boolean  :used_in_ecosystem_matrix_updates, null: false, index: true

      t.timestamps                                  null: false
    end

    add_index :responses,
              [ :exercise_uuid, :used_in_ecosystem_matrix_updates ],
              name: 'index_responses_on_ex_uuid_and_used_in_eco_mtx_updates'
  end
end
