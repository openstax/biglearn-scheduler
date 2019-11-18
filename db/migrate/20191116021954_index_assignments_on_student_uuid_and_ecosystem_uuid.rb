class IndexAssignmentsOnStudentUuidAndEcosystemUuid < ActiveRecord::Migration[5.2]
  def change
    remove_index :assignments, :student_uuid

    add_index :assignments, [ :student_uuid, :ecosystem_uuid ]
  end
end
