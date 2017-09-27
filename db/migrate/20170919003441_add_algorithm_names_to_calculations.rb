class AddAlgorithmNamesToCalculations < ActiveRecord::Migration[5.0]
  def change
    add_column :ecosystem_matrix_updates,  :algorithm_names, :string,
                                           array: true, null: false, default: []
    add_column :exercise_calculations,     :algorithm_names, :string,
                                           array: true, null: false, default: []
    add_column :student_clue_calculations, :algorithm_names, :string,
                                           array: true, null: false, default: []
    add_column :teacher_clue_calculations, :algorithm_names, :string,
                                           array: true, null: false, default: []

    reversible do |dir|
      dir.up do
        EcosystemMatrixUpdate
          .joins(:algorithm_ecosystem_matrix_updates)
          .select(:id, :algorithm_names, '"algorithm_ecosystem_matrix_updates"."algorithm_name"')
          .find_each do |ecosystem_matrix_update|
          ecosystem_matrix_update.algorithm_names << ecosystem_matrix_update.algorithm_name
          ecosystem_matrix_update.save(validate: false)
        end

        ExerciseCalculation
          .joins(:algorithm_exercise_calculations)
          .select(:id, :algorithm_names, '"algorithm_exercise_calculations"."algorithm_name"')
          .find_each do |exercise_calculation|
          exercise_calculation.algorithm_names << exercise_calculation.algorithm_name
          exercise_calculation.save(validate: false)
        end

        StudentClueCalculation
          .joins(:algorithm_student_clue_calculations)
          .select(:id, :algorithm_names, '"algorithm_student_clue_calculations"."algorithm_name"')
          .find_each do |student_clue_calculation|
          student_clue_calculation.algorithm_names << student_clue_calculation.algorithm_name
          student_clue_calculation.save(validate: false)
        end

        TeacherClueCalculation
          .joins(:algorithm_teacher_clue_calculations)
          .select(:id, :algorithm_names, '"algorithm_teacher_clue_calculations"."algorithm_name"')
          .find_each do |teacher_clue_calculation|
          teacher_clue_calculation.algorithm_names << teacher_clue_calculation.algorithm_name
          teacher_clue_calculation.save(validate: false)
        end
      end
    end

    add_index :ecosystem_matrix_updates,  :algorithm_names, using: :gin
    add_index :exercise_calculations,     :algorithm_names, using: :gin
    add_index :student_clue_calculations, :algorithm_names, using: :gin
    add_index :teacher_clue_calculations, :algorithm_names, using: :gin
  end
end
