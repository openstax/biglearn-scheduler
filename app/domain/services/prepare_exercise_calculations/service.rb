class Services::PrepareExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    ec = ExerciseCalculation.arel_table
    st = Student.arel_table
    co = Course.arel_table

    total_responses = 0
    total_assignments = 0
    total_students = 0
    loop do
      num_responses, num_students = Response.transaction do
        # Get responses that have not yet been used in exercise calculations,
        # their students' uuids and their courses' latest ecosystem_uuids
        responses = Response
          .select(:uuid, '"students"."uuid" AS "student_uuid"', '"courses"."ecosystem_uuid"')
          .joins(student: :course)
          .where(used_in_exercise_calculations: false)
          .lock('FOR NO KEY UPDATE OF "responses", "students" SKIP LOCKED')
          .take(BATCH_SIZE)

        # Also get students that don't have an ExerciseCalculation
        # for their courses' latest ecosystem
        students = Student
          .select(:uuid, :ecosystem_uuid)
          .joins(:course)
          .where(
            ExerciseCalculation.where(
              ec[:student_uuid].eq(st[:uuid]).and ec[:ecosystem_uuid].eq(co[:ecosystem_uuid])
            ).exists.not
          )
          .lock('FOR NO KEY UPDATE OF "students" SKIP LOCKED')
          .take(BATCH_SIZE)

        if responses.empty?
          next [ 0, 0 ] if students.empty?
        else
          # Record the fact that the CLUes are up-to-date with the latest Responses
          response_uuids = responses.map(&:uuid)
          Response.where(uuid: response_uuids).update_all(used_in_exercise_calculations: true)
        end

        student_uuids = responses.map(&:student_uuid) + students.map(&:uuid)

        # For each student, the ecosystems that need calculations are the course's latest
        # ecosystem plus any ecosystems used by assignments that still need SPEs or PEs
        student_uuid_ecosystem_uuid_pairs = (
          responses.map { |response| [ response.student_uuid, response.ecosystem_uuid ] } +
          students.map { |student| [ student.uuid, student.ecosystem_uuid ] } +
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

        [ responses.size, students.size ]
      end

      # If we got less responses and students than the batch size, then this is the last batch
      total_responses += num_responses
      total_students += num_students
      break if num_responses < BATCH_SIZE && num_students < BATCH_SIZE
    end

    log(:debug) do
      "#{total_responses} response(s), #{total_assignments} assignment(s) and #{total_students
      } non-response student(s) processed in #{Time.current - start_time} second(s)"
    end
  end
end
