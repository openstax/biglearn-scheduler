class Services::UpdateClueCalculations::Service < Services::ApplicationService
  def process(clue_calculation_updates:)
    relevant_calculation_uuids = clue_calculation_updates.map { |calc| calc[:calculation_uuid] }

    ActiveRecord::Base.transaction do
      student_clue_calculations_by_uuid = StudentClueCalculation
                                            .select(:uuid, :student_uuid, :algorithm_names)
                                            .where(uuid: relevant_calculation_uuids)
                                            .ordered
                                            .lock('FOR NO KEY UPDATE')
                                            .index_by(&:uuid)
      teacher_clue_calculations_by_uuid = TeacherClueCalculation
                                            .select(:uuid, :algorithm_names)
                                            .where(uuid: relevant_calculation_uuids)
                                            .ordered
                                            .lock('FOR NO KEY UPDATE')
                                            .index_by(&:uuid)

      algorithm_student_clue_calculations = []
      algorithm_teacher_clue_calculations = []
      student_clue_calculation_uuids_by_algorithm_names = Hash.new { |hash, key| hash[key] = [] }
      teacher_clue_calculation_uuids_by_algorithm_names = Hash.new { |hash, key| hash[key] = [] }
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

          student_clue_calculation_uuids_by_algorithm_names[algorithm_name] << calculation_uuid \
            unless student_clue_calculation.algorithm_names.include?(algorithm_name)

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

          teacher_clue_calculation_uuids_by_algorithm_names[algorithm_name] << calculation_uuid \
            unless teacher_clue_calculation.algorithm_names.include?(algorithm_name)

            { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
          else
            { calculation_uuid: calculation_uuid, calculation_status: 'calculation_unknown' }
          end
        end
      end

      AlgorithmStudentClueCalculation.import(
        algorithm_student_clue_calculations.sort_by(&AlgorithmStudentClueCalculation.sort_proc),
        validate: false, on_duplicate_key_update: {
          conflict_target: [ :student_clue_calculation_uuid, :algorithm_name ],
          columns: [ :uuid, :clue_data, :clue_value, :is_uploaded ]
        }
      )

      AlgorithmTeacherClueCalculation.import(
        algorithm_teacher_clue_calculations.sort_by(&AlgorithmTeacherClueCalculation.sort_proc),
        validate: false, on_duplicate_key_update: {
          conflict_target: [ :teacher_clue_calculation_uuid, :algorithm_name ],
          columns: [ :uuid, :clue_data, :is_uploaded ]
        }
      )

      student_clue_calculation_uuids_by_algorithm_names.each do |algorithm_name, uuids|
        sanitized_algorithm_name = StudentClueCalculation.sanitize(algorithm_name.downcase)

        # No order needed because already locked above
        StudentClueCalculation.where(uuid: uuids).update_all(
          "\"algorithm_names\" = \"algorithm_names\" || #{sanitized_algorithm_name}::varchar"
        )
      end

      teacher_clue_calculation_uuids_by_algorithm_names.each do |algorithm_name, uuids|
        sanitized_algorithm_name = TeacherClueCalculation.sanitize(algorithm_name.downcase)

        # No order needed because already locked above
        TeacherClueCalculation.where(uuid: uuids).update_all(
          "\"algorithm_names\" = \"algorithm_names\" || #{sanitized_algorithm_name}::varchar"
        )
      end

      # Mark any affected StudentPes (practice_worst_areas) for recalculation
      unless algorithm_student_clue_calculations.empty?
        student_pes_values_array = algorithm_student_clue_calculations.map do |calculation|
          [
            calculation.student_clue_calculation.student_uuid,
            StudentPe::CLUE_TO_EXERCISE_ALGORITHM_NAME[calculation.algorithm_name]
          ]
        end
        algorithm_exercise_calculation_join_query = <<-JOIN_SQL.strip_heredoc
          INNER JOIN (#{ValuesTable.new(student_pes_values_array)})
            AS "values" ("student_uuid", "algorithm_name")
              ON "exercise_calculations"."student_uuid" = "values"."student_uuid"
                AND "algorithm_exercise_calculations"."algorithm_name" = "values"."algorithm_name"
        JOIN_SQL

        AlgorithmExerciseCalculation
          .joins(:exercise_calculation)
          .joins(algorithm_exercise_calculation_join_query)
          .ordered_update_all(is_uploaded_for_student: false)
      end

      { clue_calculation_update_responses: clue_calculation_update_responses }
    end
  end
end
