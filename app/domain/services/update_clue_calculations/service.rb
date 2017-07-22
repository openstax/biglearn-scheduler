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
    aec = AlgorithmExerciseCalculation.arel_table
    ec = ExerciseCalculation.arel_table
    aec_queries = algorithm_student_clue_calculations.map do |algorithm_student_clue_calculation|
      clue_algorithm_name = algorithm_student_clue_calculation.algorithm_name
      exercise_algorithm_name = StudentPe::CLUE_TO_EXERCISE_ALGORITHM_NAME[clue_algorithm_name]
      student_clue_calculation = algorithm_student_clue_calculation.student_clue_calculation
      student_uuid = student_clue_calculation.student_uuid

      aec[:algorithm_name].eq(exercise_algorithm_name).and ec[:student_uuid].eq(student_uuid)
    end
    aec_query = ArelTrees.or_tree(aec_queries)
    unless aec_query.nil?
      affected_algorithm_exercise_calculation_uuids = AlgorithmExerciseCalculation
        .joins(:exercise_calculation)
        .where(aec_query)
        .pluck(:uuid)

      StudentPe.where(
        algorithm_exercise_calculation_uuid: affected_algorithm_exercise_calculation_uuids
      ).delete_all
    end

    { clue_calculation_update_responses: clue_calculation_update_responses }
  end
end
