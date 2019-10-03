class Services::PrepareExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000
  GRACE_PERIOD = 1.month

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    total_exercise_calculations = 0
    loop do
      num_exercise_calculations = ExerciseCalculation.transaction do
        old_exercise_calculation_uuids = ExerciseCalculation
          .superseded
          .where(assignment_uuids: [])
          .where(ec[:updated_at].lteq(current_time - GRACE_PERIOD))
          .ordered
          .lock('FOR UPDATE SKIP LOCKED')
          .limit(BATCH_SIZE)
          .pluck(:uuid)
        num_exercise_calculations = old_exercise_calculation_uuids.size
        next 0 if num_exercise_calculations == 0

        ExerciseCalculation.where(uuid: old_exercise_calculation_uuids).delete_all
        AlgorithmExerciseCalculation.where(
          exercise_calculation_uuid: old_exercise_calculation_uuids
        ).ordered_delete_all

        num_exercise_calculations
      end

      break if num_exercise_calculations < BATCH_SIZE
    end

    log(:debug) do
      "#{total_exercise_calculations} exercise calculation(s) removed in #{
      Time.current - start_time} second(s)"
    end
  end
end
