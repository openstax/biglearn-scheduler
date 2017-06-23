class AddIsUploadedToAlgorithmExerciseCalculationsAndSetPeExerciseUuidNotNull < ActiveRecord::Migration[5.0]
  def change
    add_column :algorithm_exercise_calculations, :is_uploaded_for_assignments, :boolean
    add_column :algorithm_exercise_calculations, :is_uploaded_for_student, :boolean

    AlgorithmExerciseCalculation.update_all(
      is_uploaded_for_assignments: true,
      is_uploaded_for_student: true
    )

    add_index :algorithm_exercise_calculations,
              :is_uploaded_for_assignments,
              name: 'index_alg_ex_calc_on_is_uploaded_for_assignments'

    add_index :algorithm_exercise_calculations,
              :is_uploaded_for_student,
              name: 'index_alg_ex_calc_on_is_uploaded_for_student'

    AssignmentPe.where(exercise_uuid: nil).delete_all
    AssignmentSpe.where(exercise_uuid: nil).delete_all
    StudentPe.where(exercise_uuid: nil).delete_all

    remove_index :assignment_pes,
                 columns: [ :assignment_uuid, :algorithm_exercise_calculation_uuid ],
                 where: '"exercise_uuid" IS NULL',
                 unique: true,
                 name: 'index_a_pes_on_a_uuid_and_alg_ex_calc_uuid'
    remove_index :assignment_spes,
                 columns: [ :assignment_uuid, :algorithm_exercise_calculation_uuid, :history_type ],
                 where: '"exercise_uuid" IS NULL',
                 unique: true,
                 name: 'index_a_spes_on_a_uuid_alg_ex_calc_uuid_and_h_type'
    remove_index :student_pes,
                 columns: [ :algorithm_exercise_calculation_uuid ],
                 where: '"exercise_uuid" IS NULL',
                 unique: true,
                 name: 'index_student_pes_on_algorithm_exercise_calculation_uuid'

    change_column_null :assignment_pes, :exercise_uuid, false
    change_column_null :assignment_spes, :exercise_uuid, false
    change_column_null :student_pes, :exercise_uuid, false
  end
end
