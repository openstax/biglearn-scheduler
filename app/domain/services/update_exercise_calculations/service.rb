class Services::UpdateExerciseCalculations::Service < Services::ApplicationService
  def process(exercise_calculation_updates:)
    calculation_uuids = exercise_calculation_updates.map { |calc| calc[:calculation_uuid] }
    ec = ExerciseCalculation.arel_table

    ExerciseCalculation.transaction do
      # The ExerciseCalculation lock ensures we don't miss updates on
      # concurrent Assignment and AlgorithmExerciseCalculation inserts
      exercise_calculations_by_uuid = ExerciseCalculation
        .select(:uuid, :student_uuid, :ecosystem_uuid, :algorithm_names)
        .where(uuid: calculation_uuids)
        .ordered
        .lock('FOR NO KEY UPDATE SKIP LOCKED')
        .index_by(&:uuid)
      exercise_calculation_uuids = exercise_calculations_by_uuid.keys

      assignment_uuids_by_exercise_calculation_uuid = Hash.new { |hash, key| hash[key] = [] }
      Assignment
        .joins(:exercise_calculation)
        .where(exercise_calculations: { uuid: exercise_calculation_uuids })
        .pluck(ec[:uuid], :uuid)
        .each do |exercise_calculation_uuid, uuid|
          assignment_uuids_by_exercise_calculation_uuid[exercise_calculation_uuid] << uuid
        end

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
          assignment_uuids = assignment_uuids_by_exercise_calculation_uuid[calculation_uuid]

          algorithm_exercise_calculations << AlgorithmExerciseCalculation.new(
            uuid: SecureRandom.uuid,
            exercise_calculation: exercise_calculation,
            algorithm_name: algorithm_name,
            ecosystem_matrix_uuid: exercise_calculation_update.fetch(:ecosystem_matrix_uuid),
            exercise_uuids: exercise_calculation_update.fetch(:exercise_uuids),
            pending_assignment_uuids: assignment_uuids,
            is_pending_for_student: true
          )

          exercise_calculation_uuids_by_algorithm_names[algorithm_name] << calculation_uuid \
            unless exercise_calculation.algorithm_names.include?(algorithm_name)

          { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
        end
      end

      unless algorithm_exercise_calculations.empty?
        algorithm_exercise_calculation_values = algorithm_exercise_calculations.map do |aec|
          [ aec.exercise_calculation_uuid, aec.algorithm_name ]
        end
        updated_aec_uuids = AlgorithmExerciseCalculation.joins(
          <<~JOIN_SQL
            INNER JOIN (#{ValuesTable.new(algorithm_exercise_calculation_values)}) AS "values"
              ("exercise_calculation_uuid", "algorithm_name")
              ON "algorithm_exercise_calculations"."exercise_calculation_uuid" =
                "values"."exercise_calculation_uuid"::uuid
                AND "algorithm_exercise_calculations"."algorithm_name" = "values"."algorithm_name"
          JOIN_SQL
        ).ordered.lock('FOR UPDATE').pluck(:uuid)

        AlgorithmExerciseCalculation.import(
          algorithm_exercise_calculations,
          validate: false, on_duplicate_key_update: {
            conflict_target: [ :exercise_calculation_uuid, :algorithm_name ],
            columns: [
              :uuid,
              :ecosystem_matrix_uuid,
              :exercise_uuids,
              :pending_assignment_uuids,
              :is_pending_for_student
            ]
          }
        )

        exercise_calculation_uuids_by_algorithm_names.each do |algorithm_name, uuids|
          sanitized_algorithm_name = ExerciseCalculation.sanitize(algorithm_name.downcase)

          # No order needed because already locked above
          ExerciseCalculation.where(uuid: uuids).update_all(
            "\"algorithm_names\" = \"algorithm_names\" || #{sanitized_algorithm_name}::varchar"
          )
        end

        # Cleanup AssignmentSpes, AssignmentPes and StudentPes that no longer have
        # an associated AlgorithmExerciseCalculation record
        AssignmentPe.where( algorithm_exercise_calculation_uuid: updated_aec_uuids).delete_all
        AssignmentSpe.where(algorithm_exercise_calculation_uuid: updated_aec_uuids).delete_all
        StudentPe.where(    algorithm_exercise_calculation_uuid: updated_aec_uuids).delete_all
      end

      { exercise_calculation_update_responses: exercise_calculation_update_responses }
    end
  end
end
