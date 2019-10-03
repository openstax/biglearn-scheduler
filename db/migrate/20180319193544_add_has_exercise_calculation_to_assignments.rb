class AddHasExerciseCalculationToAssignments < ActiveRecord::Migration[5.0]
  def change
    add_column :assignments, :has_exercise_calculation, :boolean

    reversible do |dir|
      dir.up do
        aa = Assignment.arel_table
        ec = ExerciseCalculation.arel_table
        st = Student.arel_table

        Assignment.joins(:student).where(
          ExerciseCalculation.where(
            ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(aa[:ecosystem_uuid])
          ).arel.exists
        ).update_all(has_exercise_calculation: true)

        Assignment.where(has_exercise_calculation: nil).update_all(has_exercise_calculation: false)
      end
    end

    change_column_null :assignments, :has_exercise_calculation, false
    add_index :assignments, :has_exercise_calculation
  end
end
