class Services::UpdateExerciseCalculations::Service
  def process(exercise_calculation_updates:)
    relevant_calculation_uuids = exercise_calculation_updates.map { |calc| calc[:calculation_uuid] }
    assignment_spe_calculations_by_uuid =
      AssignmentSpeCalculation.where(uuid: relevant_calculation_uuids).index_by(&:uuid)
    assignment_pe_calculations_by_uuid =
      AssignmentPeCalculation.where(uuid: relevant_calculation_uuids).index_by(&:uuid)
    student_pe_calculations_by_uuid =
      StudentPeCalculation.where(uuid: relevant_calculation_uuids).index_by(&:uuid)

    algorithm_assignment_spe_calculations = []
    algorithm_assignment_pe_calculations = []
    algorithm_student_pe_calculations = []
    exercise_calculation_update_responses =
      exercise_calculation_updates.map do |exercise_calculation_update|
      calculation_uuid = exercise_calculation_update.fetch(:calculation_uuid)
      algorithm_name = exercise_calculation_update.fetch(:algorithm_name)
      exercise_uuids = exercise_calculation_update.fetch(:exercise_uuids)

      assignment_spe_calculation = assignment_spe_calculations_by_uuid[calculation_uuid]
      if assignment_spe_calculation.present?
        algorithm_assignment_spe_calculations << AlgorithmAssignmentSpeCalculation.new(
          uuid: SecureRandom.uuid,
          assignment_spe_calculation_uuid: calculation_uuid,
          algorithm_name: algorithm_name,
          exercise_uuids: exercise_uuids,
          assignment_uuid: assignment_spe_calculation.assignment_uuid,
          student_uuid: assignment_spe_calculation.student_uuid
        )

        { calculation_status: 'calculation_accepted' }
      else
        assignment_pe_calculation = assignment_pe_calculations_by_uuid[calculation_uuid]

        if assignment_pe_calculation.present?
          algorithm_assignment_pe_calculations << AlgorithmAssignmentPeCalculation.new(
            uuid: SecureRandom.uuid,
            assignment_pe_calculation_uuid: calculation_uuid,
            algorithm_name: algorithm_name,
            exercise_uuids: exercise_uuids,
            assignment_uuid: assignment_pe_calculation.assignment_uuid,
            student_uuid: assignment_pe_calculation.student_uuid
          )

          { calculation_status: 'calculation_accepted' }
        else
          student_pe_calculation = student_pe_calculations_by_uuid[calculation_uuid]

          if student_pe_calculation.present?
            algorithm_student_pe_calculations << AlgorithmStudentPeCalculation.new(
              uuid: SecureRandom.uuid,
              student_pe_calculation_uuid: calculation_uuid,
              algorithm_name: algorithm_name,
              exercise_uuids: exercise_uuids,
              student_uuid: student_pe_calculation.student_uuid
            )

            { calculation_status: 'calculation_accepted' }
          else
            { calculation_status: 'calculation_unknown' }
          end
        end
      end
    end

    AlgorithmAssignmentSpeCalculation.import(
      algorithm_assignment_spe_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :assignment_spe_calculation_uuid, :algorithm_name ],
        columns: [ :exercise_uuids ]
      }
    )

    AlgorithmAssignmentPeCalculation.import(
      algorithm_assignment_pe_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :assignment_pe_calculation_uuid, :algorithm_name ],
        columns: [ :exercise_uuids ]
      }
    )

    AlgorithmStudentPeCalculation.import(
      algorithm_student_pe_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :student_pe_calculation_uuid, :algorithm_name ],
        columns: [ :exercise_uuids ]
      }
    )

    { exercise_calculation_update_responses: exercise_calculation_update_responses }
  end
end
