class ResetAndRenameUsedInEcosystemMatrixUpdatesToUsedInResponseCount < ActiveRecord::Migration[5.0]
  def change
    remove_index :responses, column: [ :exercise_uuid, :used_in_ecosystem_matrix_updates ],
                             name: 'index_responses_on_ex_uuid_and_used_in_eco_mtx_updates'
    remove_index :responses, :used_in_ecosystem_matrix_updates

    change_column_default :responses, :used_in_ecosystem_matrix_updates, from: nil, to: false

    remove_column :responses, :used_in_ecosystem_matrix_updates, :boolean,
                  null: false, default: false

    add_column :responses, :used_in_response_count, :boolean, null: false, default: false

    change_column_default :responses, :used_in_response_count, from: false, to: nil

    add_index :responses, :exercise_uuid
    add_index :responses, :used_in_response_count
  end
end
