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
        # Get responses not yet used in exercise calculations and their students' uuids
        # No order needed because of SKIP LOCKED
        responses = Response
          .joins(:student)
          .where(is_used_in_exercise_calculations: false)
          .lock('FOR NO KEY UPDATE OF "responses", "students" SKIP LOCKED')
          .limit(BATCH_SIZE)
          .pluck(:uuid, st[:uuid])
        response_student_uuids = responses.map(&:second)

        # Get the latest course ecosystem UUID for each student above and also include other
        # students that don't have an ExerciseCalculation for their courses' latest ecosystem
        # No order needed because of SKIP LOCKED
        course_pairs = Student
          .where(uuid: response_student_uuids).or(
            Student.where.not(
              ExerciseCalculation.where(
                ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(co[:ecosystem_uuid])
              ).arel.exists
            )
          )
          .joins(:course)
          .lock('FOR NO KEY UPDATE OF "students" SKIP LOCKED')
          .limit(BATCH_SIZE)
          .pluck(:uuid, :ecosystem_uuid)

        # Get the ecosystem UUIDs for assignments that need SPEs or PEs for each student above
        # and also include other students that are missing assignment ExerciseCalculations
        # No order needed because of SKIP LOCKED
        assignment_pairs = Assignment
          .where(student_uuid: response_student_uuids)
          .or(
            Assignment.where(has_exercise_calculation: false).where.not(
              ExerciseCalculation.where(
                ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(aa[:ecosystem_uuid])
              ).arel.exists
            )
          )
          .joins(:student)
          .need_pes_or_spes
          .lock('FOR NO KEY UPDATE OF "students" SKIP LOCKED')
          .limit(BATCH_SIZE)
          .pluck(st[:uuid], :ecosystem_uuid)

        num_responses = responses.size
        if num_responses > 0
          # Record the fact that the CLUes are up-to-date with the latest Responses
          response_uuids = responses.map(&:first)
          # No order needed because already locked above
          Response.where(uuid: response_uuids).update_all(is_used_in_exercise_calculations: true)
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
            student_uuid: student_uuid,
            is_used_in_assignments: false
          )
        end

        # Mark old ExerciseCalculations as superseded
        exercise_calculation_values_array = exercise_calculations.map do |calculation|
          [ calculation.student_uuid, calculation.ecosystem_uuid ]
        end
        ExerciseCalculation.joins(
          <<~JOIN_SQL
            INNER JOIN (#{ValuesTable.new(exercise_calculation_values_array)})
              AS "values" ("student_uuid", "ecosystem_uuid")
              ON "exercise_calculations"."student_uuid" = "values"."student_uuid"::uuid
                AND "exercise_calculations"."ecosystem_uuid" = "values"."ecosystem_uuid"::uuid
          JOIN_SQL
        ).where(superseded_at: nil).update_all superseded_at: start_time

        # Record the ExerciseCalculations
        ExerciseCalculation.import(
          exercise_calculations.sort_by(&ExerciseCalculation.sort_proc), validate: false
        )

        # Mark assignments that got new calculations (and any others we might have missed)
        mark_assignments_with_calculations(ec, st, aa)

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
    # We don't care about missing assignments here because we call this method every iteration
    # No order needed because of SKIP LOCKED
    assignment_uuids = Assignment
      .joins(:student)
      .need_pes_or_spes
      .where(has_exercise_calculation: false)
      .where(
        ExerciseCalculation.where(
          ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(aa[:ecosystem_uuid])
        ).arel.exists
      )
      .lock('FOR NO KEY UPDATE OF "assignments" SKIP LOCKED')
      .pluck(:uuid)

    Assignment.where(uuid: assignment_uuids).update_all(has_exercise_calculation: true)
  end
end
