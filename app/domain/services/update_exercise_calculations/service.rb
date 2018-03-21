class Services::UpdateExerciseCalculations::Service < Services::ApplicationService
  def process(exercise_calculation_updates:)
    calculation_uuids = exercise_calculation_updates.map { |calc| calc[:calculation_uuid] }

    ExerciseCalculation.transaction do
      exercise_calculations_by_uuid = ExerciseCalculation.select(:uuid, :algorithm_names)
                                                         .where(uuid: calculation_uuids)
                                                         .order(:student_uuid, :ecosystem_uuid)
                                                         .lock('FOR NO KEY UPDATE')
                                                         .index_by(&:uuid)

      algorithm_exercise_calculations = []
      exercise_calculation_uuids_by_algorithm_names = Hash.new { |hash, key| hash[key] = [] }
      exercise_calculation_update_responses =
        exercise_calculation_updates.map do |exercise_calculation_update|
        calculation_uuid = exercise_calculation_update.fetch(:calculation_uuid)

        exercise_calculation = exercise_calculations_by_uuid[calculation_uuid]
        if exercise_calculation.nil?
          { calculation_uuid: calculation_uuid, calculation_status: 'calculation_unknown' }
        else
          algorithm_name = exercise_calculation_update.fetch(:algorithm_name)

          algorithm_exercise_calculations << AlgorithmExerciseCalculation.new(
            uuid: SecureRandom.uuid,
            exercise_calculation: exercise_calculation,
            algorithm_name: algorithm_name,
            exercise_uuids: exercise_calculation_update.fetch(:exercise_uuids),
            is_uploaded_for_assignments: false,
            is_uploaded_for_student: false
          )

          exercise_calculation_uuids_by_algorithm_names[algorithm_name] << calculation_uuid \
            unless exercise_calculation.algorithm_names.include?(algorithm_name)

          { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
        end
      end

      AlgorithmExerciseCalculation.import(
        algorithm_exercise_calculations, validate: false, on_duplicate_key_update: {
          conflict_target: [ :exercise_calculation_uuid, :algorithm_name ],
          columns: [
            :uuid, :exercise_uuids, :is_uploaded_for_assignments, :is_uploaded_for_student
          ]
        }
      )

      exercise_calculation_uuids_by_algorithm_names.each do |algorithm_name, uuids|
        sanitized_algorithm_name = ExerciseCalculation.sanitize(algorithm_name.downcase)

        ExerciseCalculation.where(uuid: uuids).update_all(
          "\"algorithm_names\" = \"algorithm_names\" || #{sanitized_algorithm_name}::varchar"
        )
      end

      # Cleanup AssignmentSpes, AssignmentPes and StudentPes that no longer have
      # an associated AlgorithmExerciseCalculation record
      AssignmentPe.unassociated.delete_all
      AssignmentSpe.unassociated.delete_all
      StudentPe.unassociated.delete_all

      { exercise_calculation_update_responses: exercise_calculation_update_responses }
    end
  end
end
