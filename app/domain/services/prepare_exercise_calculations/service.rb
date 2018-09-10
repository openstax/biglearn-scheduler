class Services::PrepareExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    ec = ExerciseCalculation.arel_table
    st = Student.arel_table
    co = Course.arel_table
    aa = Assignment.arel_table

    total_responses = 0
    total_course_pairs = 0
    total_assignment_pairs = 0
    loop do
      num_responses, num_course_pairs, num_assignment_pairs = Response.transaction do
        # Get responses that have not yet been used in exercise calculations,
        # their students' uuids and their courses' latest ecosystem_uuids
        responses = Response
          .joins(:student)
          .where(used_in_exercise_calculations: false)
          .lock('FOR NO KEY UPDATE OF "responses", "students" SKIP LOCKED')
          .limit(BATCH_SIZE)
          .pluck(:uuid, '"students"."uuid"')
        response_student_uuids = responses.map(&:second)

        # Get the latest course ecosystem UUID for each student above and also include other
        # students that don't have an ExerciseCalculation for their courses' latest ecosystem
        course_pairs = Student
          .where(uuid: response_student_uuids).or(
            Student.where(
              ExerciseCalculation.where(
                ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(co[:ecosystem_uuid])
              ).exists.not
            )
          )
          .joins(:course)
          .lock('FOR NO KEY UPDATE OF "students" SKIP LOCKED')
          .limit(BATCH_SIZE)
          .pluck(:uuid, :ecosystem_uuid)

        # Get the ecosystem UUIDs for assignments that need SPEs or PEs for each student above
        # and also include other students that are missing assignment ExerciseCalculations
        assignment_pairs = Assignment
          .where(student_uuid: response_student_uuids)
          .or(
            Assignment.where(has_exercise_calculation: false).where(
              ExerciseCalculation.where(
                ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(aa[:ecosystem_uuid])
              ).exists.not
            )
          )
          .joins(:student)
          .need_pes_or_spes
          .lock('FOR NO KEY UPDATE OF "students" SKIP LOCKED')
          .limit(BATCH_SIZE)
          .pluck('"students"."uuid"', :ecosystem_uuid)

        num_responses = responses.size
        if num_responses > 0
          # Record the fact that the CLUes are up-to-date with the latest Responses
          response_uuids = responses.map(&:first)
          Response.where(uuid: response_uuids).update_all(used_in_exercise_calculations: true)
        end

        student_uuid_ecosystem_uuid_pairs = (course_pairs + assignment_pairs).uniq
        if student_uuid_ecosystem_uuid_pairs.empty?
          # Check if we missed any assignments that already have calculations
          mark_assignments_with_calculations(ec, st, aa)
          next [ num_responses, 0, 0 ]
        end

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
            conflict_target: [ :student_uuid, :ecosystem_uuid ],
            columns: [ :uuid, :algorithm_names ]
          }
        )

        # Mark assignments that got new calculations (and any others we might have missed)
        mark_assignments_with_calculations(ec, st, aa)

        # Cleanup AlgorithmExerciseCalculations that no longer have
        # an associated ExerciseCalculation record
        AlgorithmExerciseCalculation.unassociated.delete_all

        [ num_responses, course_pairs.size, assignment_pairs.size ]
      end

      # If we got less responses and students than the batch size, then this is the last batch
      total_responses += num_responses
      total_course_pairs += num_course_pairs
      total_assignment_pairs += num_assignment_pairs
      break if num_responses < BATCH_SIZE &&
               num_course_pairs < BATCH_SIZE &&
               num_assignment_pairs < BATCH_SIZE
    end

    log(:debug) do
      "#{total_responses} response(s), #{total_course_pairs} updated course(s)/new student(s) and #{
      total_assignment_pairs} assignment(s) processed in #{Time.current - start_time} second(s)"
    end
  end

  def mark_assignments_with_calculations(ec, st, aa)
    # Check if any assignments with has_exercise_calculation: false
    # already have calculations and need to be updated
    Assignment.joins(:student).need_pes_or_spes.where(has_exercise_calculation: false).where(
      ExerciseCalculation.where(
        ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(aa[:ecosystem_uuid])
      ).exists
    ).update_all(has_exercise_calculation: true)
  end
end
