class Services::PrepareExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'PrepareExerciseCalculations' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    st = Student.arel_table
    co = Course.arel_table
    ec = ExerciseCalculation.arel_table
    re = Response.arel_table

    # Do all the processing in batches to avoid OOM problems
    total_students = 0
    loop do
      num_students = Student.transaction do
        # Get Students that don't have an ExerciseCalculation for their Courses' latest
        # ecosystem or that have a response that has not yet been used in ExerciseCalculations
        # Also return the Students' Courses' latest ecosystems
        students = Student
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
          .select([:uuid, :ecosystem_uuid])
          .lock
          .take(BATCH_SIZE)
        student_uuids = students.map(&:uuid)

        # For each student, the ecosystems that need calculations are the course's latest
        # ecosystem plus any ecosystems used by assignments that still need SPEs or PEs
        ecosystem_uuid_student_uuid_pairs = (
          students.map { |student| [ student.ecosystem_uuid, student.uuid ] } +
          Assignment.need_spes_or_pes
                    .where(student_uuid: student_uuids)
                    .pluck(:ecosystem_uuid, :student_uuid)
        ).uniq

        # Create the ExerciseCalculations
        exercise_calculations = ecosystem_uuid_student_uuid_pairs
                                  .map do |ecosystem_uuid, student_uuid|
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
        Response.where(student_uuid: student_uuids).update_all(used_in_exercise_calculations: true)

        students.size
      end

      # If we got less students than the batch size, then this is the last batch
      total_students += num_students
      break if num_students < BATCH_SIZE
    end

    Rails.logger.tagged 'PrepareExerciseCalculations' do |logger|
      logger.debug do
        "#{total_students} student(s) processed in #{Time.now - start_time} second(s)"
      end
    end
  end
end
