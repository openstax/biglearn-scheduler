class Services::PrepareExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    st = Student.arel_table
    co = Course.arel_table
    ec = ExerciseCalculation.arel_table
    re = Response.arel_table

    # Do all the processing in batches to avoid OOM problems
    total_students = 0
    loop do
      num_students = Student.transaction do
        # Get Students that don't have an ExerciseCalculation for their Courses' latest ecosystem
        # or that have a response that has not yet been used in ExerciseCalculations
        # Also return the Students' Courses' latest ecosystems
        student_uuid_ecosystem_uuid_pairs = Student
          .where(
            ExerciseCalculation.where(
              ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(co[:ecosystem_uuid])
            ).exists.not
          ).or(
            Student.where(
              Response.where(
                re[:student_uuid].eq(st[:uuid]).and re[:used_in_exercise_calculations].eq(false)
              ).exists
            )
          )
          .joins(:course)
          .limit(BATCH_SIZE)
          .lock('FOR NO KEY UPDATE OF "students" SKIP LOCKED')
          .pluck(:uuid, :ecosystem_uuid)
        next 0 if student_uuid_ecosystem_uuid_pairs.empty?

        student_uuids = student_uuid_ecosystem_uuid_pairs.map(&:first)

        # We lock the Responses here to avoid deadlocks when updating them later
        response_uuids = Response
          .where(student_uuid: student_uuids, used_in_exercise_calculations: false)
          .lock('FOR NO KEY UPDATE SKIP LOCKED')
          .pluck(:uuid)

        # For each student, the ecosystems that need calculations are the course's latest
        # ecosystem plus any ecosystems used by assignments that still need SPEs or PEs
        student_uuid_ecosystem_uuid_pairs = (
          student_uuid_ecosystem_uuid_pairs +
          Assignment.need_spes_or_pes
                    .where(student_uuid: student_uuids)
                    .pluck(:student_uuid, :ecosystem_uuid)
        ).uniq

        # Create the ExerciseCalculations
        exercise_calculations = student_uuid_ecosystem_uuid_pairs
                                  .map do |student_uuid, ecosystem_uuid|
          ExerciseCalculation.new(
            uuid: SecureRandom.uuid,
            ecosystem_uuid: ecosystem_uuid,
            student_uuid: student_uuid
          )
        end

        # Record the ExerciseCalculations
        ExerciseCalculation.import(
          exercise_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [ :student_uuid, :ecosystem_uuid ], columns: [ :uuid ]
          }
        )

        # Cleanup AlgorithmExerciseCalculations that no longer have
        # an associated ExerciseCalculation record
        AlgorithmExerciseCalculation.unassociated.delete_all

        # Record the fact that the CLUes are up-to-date with the latest Responses
        Response.where(uuid: response_uuids).update_all(used_in_exercise_calculations: true)

        student_uuids.size
      end

      # If we got less students than the batch size, then this is the last batch
      total_students += num_students
      break if num_students < BATCH_SIZE
    end

    log(:debug) do
      "#{total_students} student(s) processed in #{Time.current - start_time} second(s)"
    end
  end
end
