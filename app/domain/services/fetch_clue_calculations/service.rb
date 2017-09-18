class Services::FetchClueCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 100

  def process(algorithm_name:)
    sanitized_algo_name = ActiveRecord::Base.sanitize algorithm_name

    student_clue_calculations = []
    teacher_clue_calculations = []
    ActiveRecord::Base.transaction do
      # Extra memory is required to perform the hash anti-join efficiently
      ActiveRecord::Base.connection.execute 'SET LOCAL work_mem=20480'

      student_clue_calculations = StudentClueCalculation.where.not(
        AlgorithmStudentClueCalculation.where(
          <<-WHERE_SQL.strip_heredoc
            "algorithm_student_clue_calculations"."student_clue_calculation_uuid" =
              "student_clue_calculations"."uuid"
              AND "algorithm_student_clue_calculations"."algorithm_name" = #{sanitized_algo_name}
          WHERE_SQL
        ).exists
      ).take(BATCH_SIZE)

      teacher_clue_calculations = TeacherClueCalculation.where.not(
        AlgorithmTeacherClueCalculation.where(
          <<-WHERE_SQL.strip_heredoc
            "algorithm_teacher_clue_calculations"."teacher_clue_calculation_uuid" =
              "teacher_clue_calculations"."uuid"
              AND "algorithm_teacher_clue_calculations"."algorithm_name" = #{sanitized_algo_name}
          WHERE_SQL
        ).exists
      ).take(BATCH_SIZE)
    end

    clue_calculations = student_clue_calculations + teacher_clue_calculations
    clue_calculation_responses = clue_calculations.map do |clue_calculation|
      {
        calculation_uuid: clue_calculation.uuid,
        ecosystem_uuid: clue_calculation.ecosystem_uuid,
        student_uuids: clue_calculation.student_uuids,
        exercise_uuids: clue_calculation.exercise_uuids,
        responses: clue_calculation.responses
      }
    end

    { clue_calculations: clue_calculation_responses }
  end
end
