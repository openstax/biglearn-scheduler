class CreateAssignedExercises < ActiveRecord::Migration[5.0]
  def change
    create_table :assigned_exercises do |t|
      t.uuid    :uuid,            null: false, index: { unique: true }
      t.uuid    :assignment_uuid, null: false
      t.boolean :is_spe,          null: false
      t.boolean :is_pe,           null: false

      t.timestamps                null: false
    end

    add_index :assigned_exercises,
              [:assignment_uuid, :is_spe, :is_pe],
              name: 'index_assigned_exercises_on_a_uuid_and_is_spe_and_is_pe'
  end
end
