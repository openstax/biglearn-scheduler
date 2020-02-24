class IndexActiveExerciseCalculationsOnStudentUuidAndEcosystemUuid < ActiveRecord::Migration[5.2]
  def change
    add_index :exercise_calculations, [ :student_uuid, :ecosystem_uuid ],
              where: '"superseded_at" IS NULL',
              name: 'index_active_ex_calc_on_student_uuid_and_ecosystem_uuid'
  end
end
