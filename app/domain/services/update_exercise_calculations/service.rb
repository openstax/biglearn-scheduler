class Services::UpdateExerciseCalculations::Service < Services::ApplicationService
  def process(exercise_calculation_updates:)
    calculation_uuids = exercise_calculation_updates.map { |calc| calc[:calculation_uuid] }
    exercise_calculations_by_uuid = ExerciseCalculation.where(uuid: calculation_uuids)
                                                       .select(:uuid)
                                                       .index_by(&:uuid)

    algorithm_exercise_calculations = []
    exercise_calculation_update_responses =
      exercise_calculation_updates.map do |exercise_calculation_update|
      calculation_uuid = exercise_calculation_update.fetch(:calculation_uuid)

      exercise_calculation = exercise_calculations_by_uuid[calculation_uuid]
      if exercise_calculation.nil?
        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_unknown' }
      else
        algorithm_exercise_calculations << AlgorithmExerciseCalculation.new(
          uuid: SecureRandom.uuid,
          exercise_calculation: exercise_calculation,
          algorithm_name: exercise_calculation_update.fetch(:algorithm_name),
          exercise_uuids: exercise_calculation_update.fetch(:exercise_uuids)
        )

        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
      end
    end

    AlgorithmExerciseCalculation.import(
      algorithm_exercise_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :exercise_calculation_uuid, :algorithm_name ],
        columns: [ :uuid, :exercise_uuids ]
      }
    )

    # Cleanup AssignmentSpes, AssignmentPes and StudentPes that no longer have
    # an associated AlgorithmExerciseCalculation record
    AssignmentSpe.unassociated.delete_all
    AssignmentPe.unassociated.delete_all
    StudentPe.unassociated.delete_all

    { exercise_calculation_update_responses: exercise_calculation_update_responses }
  end
end
