class Services::UpdateClueCalculations::Service < Services::ApplicationService
  def process(clue_calculation_updates:)
    relevant_calculation_uuids = clue_calculation_updates.map { |calc| calc[:calculation_uuid] }
    student_clue_calculations_by_uuid = StudentClueCalculation
                                          .where(uuid: relevant_calculation_uuids)
                                          .select(:uuid, :student_uuid)
                                          .index_by(&:uuid)
    teacher_clue_calculations_by_uuid = TeacherClueCalculation
                                          .where(uuid: relevant_calculation_uuids)
                                          .select(:uuid)
                                          .index_by(&:uuid)

    algorithm_student_clue_calculations = []
    algorithm_teacher_clue_calculations = []
    clue_calculation_update_responses = clue_calculation_updates.map do |clue_calculation_update|
      calculation_uuid = clue_calculation_update.fetch(:calculation_uuid)
      algorithm_name = clue_calculation_update.fetch(:algorithm_name)
      clue_data = clue_calculation_update.fetch(:clue_data)

      student_clue_calculation = student_clue_calculations_by_uuid[calculation_uuid]
      if student_clue_calculation.present?
        algorithm_student_clue_calculations << AlgorithmStudentClueCalculation.new(
          uuid: SecureRandom.uuid,
          student_clue_calculation: student_clue_calculation,
          algorithm_name: algorithm_name,
          clue_data: clue_data,
          clue_value: clue_data.fetch(:most_likely),
          is_uploaded: false
        )

        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
      else
        teacher_clue_calculation = teacher_clue_calculations_by_uuid[calculation_uuid]
        if teacher_clue_calculation.present?
          algorithm_teacher_clue_calculations << AlgorithmTeacherClueCalculation.new(
            uuid: SecureRandom.uuid,
            teacher_clue_calculation: teacher_clue_calculation,
            algorithm_name: algorithm_name,
            clue_data: clue_data,
            is_uploaded: false
          )

          { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
        else
          { calculation_uuid: calculation_uuid, calculation_status: 'calculation_unknown' }
        end
      end
    end

    AlgorithmStudentClueCalculation.import(
      algorithm_student_clue_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :student_clue_calculation_uuid, :algorithm_name ],
        columns: [ :uuid, :clue_data, :clue_value, :is_uploaded ]
      }
    )

    AlgorithmTeacherClueCalculation.import(
      algorithm_teacher_clue_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :teacher_clue_calculation_uuid, :algorithm_name ],
        columns: [ :uuid, :clue_data, :is_uploaded ]
      }
    )

    # Mark any affected StudentPes (practice_worst_areas) for recalculation
    unless algorithm_student_clue_calculations.empty?
      student_pes_values_array = algorithm_student_clue_calculations.map do |calculation|
        [
          calculation.student_clue_calculation.student_uuid,
          StudentPe::CLUE_TO_EXERCISE_ALGORITHM_NAME[calculation.algorithm_name]
        ]
      end
      student_pes_join_query = <<-JOIN_SQL.strip_heredoc
        INNER JOIN (#{ValuesTable.new(student_pes_values_array)})
          AS "values" ("student_uuid", "algorithm_name")
            ON "exercise_calculations"."student_uuid" = "values"."student_uuid"
              AND "algorithm_exercise_calculations"."algorithm_name" = "values"."algorithm_name"
      JOIN_SQL

      StudentPe
        .joins(algorithm_exercise_calculation: :exercise_calculation)
        .joins(student_pes_join_query)
        .delete_all
    end

    { clue_calculation_update_responses: clue_calculation_update_responses }
  end
end
