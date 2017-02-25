class Services::UpdateClues::Service
  Z_ALPHA = 0.68

  def process
    start_time = Time.now
    Rails.logger.tagged 'UpdateClues' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    # An Ecosystem update or any Responses created/updated after the last CLUe update
    # indicate the need for new CLUes
    rsp = Response.arel_table
    cc = Course.arel_table
    ee = EcosystemExercise.arel_table

    response_query = rsp[:used_in_clues_for_ecosystem_uuid].eq(nil).or(
      cc[:ecosystem_uuid].not_eq(rsp[:used_in_clues_for_ecosystem_uuid])
    )
    new_responses = Response.joins(student: :course).where(response_query).to_a

    # Build some hashes to minimize the number of queries

    # Map the students to courses and course containers
    student_uuids = new_responses.map(&:student_uuid)
    course_uuid_by_student_uuid = {}
    course_container_uuids_by_student_uuids = {}
    Student.where(uuid: student_uuids)
           .pluck(:uuid, :course_uuid, :course_container_uuids)
           .each do |uuid, course_uuid, course_container_uuids|
      course_uuid_by_student_uuid[uuid] = course_uuid
      course_container_uuids_by_student_uuids[uuid] = course_container_uuids
    end

    # Map the course containers back to students
    course_container_uuids = course_container_uuids_by_student_uuids.values.flatten
    student_uuids_by_course_container_uuids = CourseContainer.where(uuid: course_container_uuids)
                                                             .pluck(:uuid, :student_uuids)
                                                             .to_h

    # Map the courses to ecosystems
    course_uuids = course_uuid_by_student_uuid.values
    ecosystem_uuid_by_course_uuid = Course.where(uuid: course_uuids)
                                          .pluck(:uuid, :ecosystem_uuid)
                                          .to_h

    # Map the exercise_uuids to exercise_group_uuids
    exercise_uuids = new_responses.map(&:exercise_uuid)
    exercise_group_uuid_by_exercise_uuid = Exercise.where(uuid: exercise_uuids)
                                                   .pluck(:uuid, :group_uuid)
                                                   .to_h

    # Build a query to obtain the book_container_uuids for the new Responses
    processable_new_responses = []
    ee_queries = new_responses.map do |response|
      student_uuid = response.student_uuid

      course_uuid = course_uuid_by_student_uuid[student_uuid]
      if course_uuid.nil?
        Rails.logger.tagged('UpdateClues') do |logger|
          logger.warn { "New response skipped due to no information about student #{student_uuid}" }
        end

        next
      end

      ecosystem_uuid = ecosystem_uuid_by_course_uuid[course_uuid]
      if ecosystem_uuid.nil?
        Rails.logger.tagged('UpdateClues') do |logger|
          logger.warn { "New response skipped due to no information about course #{course_uuid}" }
        end

        next
      end

      exercise_uuid = response.exercise_uuid
      exercise_group_uuid = exercise_group_uuid_by_exercise_uuid[exercise_uuid]
      if exercise_group_uuid.nil?
        Rails.logger.tagged('UpdateClues') do |logger|
          logger.warn do
            "New response skipped due to no information about exercise #{exercise_uuid}"
          end
        end

        next
      end

      response.used_in_clues_for_ecosystem_uuid = ecosystem_uuid
      processable_new_responses << response

      ee[:ecosystem_uuid].eq(ecosystem_uuid).and(ee[:exercise_group_uuid].eq(exercise_group_uuid))
    end.compact.reduce(:or)

    # Map the ecosystem_uuids and exercise_group_uuids to book_container_uuids
    book_container_uuids_map = Hash.new { |hash, key| hash[key] = {} }
    EcosystemExercise.where(ee_queries)
                     .pluck(:ecosystem_uuid, :exercise_group_uuid, :book_container_uuids)
                     .each do |ecosystem_uuid, exercise_group_uuid, book_container_uuids|
      book_container_uuids_map[ecosystem_uuid][exercise_group_uuid] = book_container_uuids
    end

    # Map the book_container_uuids to ecosystem_uuids and back to exercise_uuids
    book_container_uuids = book_container_uuids_map.values.map(&:values).flatten
    ecosystem_uuid_by_book_container_uuid = {}
    exercise_uuids_by_book_container_uuids = Hash.new { |hash, key| hash[key] = [] }
    ExercisePool.where(book_container_uuid: book_container_uuids)
                .pluck(:ecosystem_uuid, :book_container_uuid, :exercise_uuids, :use_for_clue)
                .each do |ecosystem_uuid, book_container_uuid, exercise_uuids, use_for_clue|
      ecosystem_uuid_by_book_container_uuid[book_container_uuid] = ecosystem_uuid
      next unless use_for_clue

      exercise_uuids_by_book_container_uuids[book_container_uuid].concat exercise_uuids
    end

    # Find all relevant exercise group_uuids
    # (all exercise group_uuids in the matching book_containers)
    exercise_uuids = exercise_uuids_by_book_container_uuids.values.flatten
    exercise_group_uuids = Exercise.where(uuid: exercise_uuids).pluck(:group_uuid)

    # Re-map the exercise_uuids to exercise_group_uuids since we might have different exercises now
    exercise_group_uuid_by_exercise_uuid = Exercise.where(group_uuid: exercise_group_uuids)
                                                   .pluck(:uuid, :group_uuid)
                                                   .to_h

    # Collect the CLUes that need to be updated and build the final Response query
    student_clues_to_update = Hash.new { |hash, key| hash[key] = [] }
    teacher_clues_to_update = Hash.new { |hash, key| hash[key] = [] }
    response_queries = processable_new_responses.map do |response|
      student_uuid = response.student_uuid
      exercise_uuid = response.exercise_uuid
      ecosystem_uuid = response.used_in_clues_for_ecosystem_uuid
      exercise_group_uuid = exercise_group_uuid_by_exercise_uuid[exercise_uuid]

      # Find all book containers that contain the given exercise and all exercises in all of them
      # exercise_group_uuid can be nil here...
      # this simply means the exercise was removed from the book and should not count for CLUes
      book_container_uuids = book_container_uuids_map[ecosystem_uuid].fetch exercise_group_uuid, []
      exercise_uuids = \
        exercise_uuids_by_book_container_uuids.values_at(*book_container_uuids).flatten

      # Find all course containers that contain the given student
      course_container_uuids = course_container_uuids_by_student_uuids.fetch student_uuid, []

      book_container_uuids.each do |book_container_uuid|
        student_clues_to_update[book_container_uuid] << student_uuid

        teacher_clues_to_update[book_container_uuid].concat course_container_uuids
      end

      # All responses from students in the same course containers
      # that refer to any exercise in the same book containers should be considered
      student_uuids = \
        student_uuids_by_course_container_uuids.values_at(*course_container_uuids).flatten
      rsp[:student_uuid].in(student_uuids).and rsp[:exercise_uuid].in(exercise_uuids)
    end.compact.reduce(:or)

    # Map student_uuids and exercise_group_uuids to correctness information
    # Take only the latest answer for each exercise_group_uuid
    responses_map = Hash.new { |hash, key| hash[key] = {} }
    Response.where(response_queries)
            .order(:responded_at)
            .pluck(:student_uuid, :exercise_uuid, :is_correct)
            .each do |student_uuid, exercise_uuid, is_correct|
      exercise_group_uuid = exercise_group_uuid_by_exercise_uuid[exercise_uuid]
      if exercise_group_uuid.nil?
        Rails.logger.tagged('UpdateClues') do |logger|
          logger.warn { "Response skipped due to no information about exercise #{exercise_uuid}" }
        end

        next
      end

      responses_map[student_uuid][exercise_group_uuid] = is_correct
    end

    # Calculate student CLUes
    student_clues = student_clues_to_update.flat_map do |book_container_uuid, student_uuids|
      ecosystem_uuid = ecosystem_uuid_by_book_container_uuid[book_container_uuid]
      if ecosystem_uuid.nil?
        Rails.logger.tagged('UpdateClues') do |logger|
          logger.warn do
            "Student CLUe skipped due to no information about book container #{book_container_uuid}"
          end
        end

        next
      end

      exercise_uuids = exercise_uuids_by_book_container_uuids[book_container_uuid]
      exercise_group_uuids = exercise_group_uuid_by_exercise_uuid.values_at(*exercise_uuids)
                                                                 .compact
                                                                 .uniq

      student_uuids.uniq.map do |student_uuid|
        student_responses = responses_map[student_uuid]
        responses = student_responses.values_at(*exercise_group_uuids).compact.flatten
        clue_data = calculate_clue_data(responses).merge(ecosystem_uuid: ecosystem_uuid)

        {
          student_uuid: student_uuid,
          book_container_uuid: book_container_uuid,
          clue_data: clue_data
        }
      end
    end.compact

    # Calculate teacher CLUes
    teacher_clues = \
      teacher_clues_to_update.flat_map do |book_container_uuid, course_container_uuids|
      ecosystem_uuid = ecosystem_uuid_by_book_container_uuid[book_container_uuid]
      if ecosystem_uuid.nil?
        Rails.logger.tagged('UpdateClues') do |logger|
          logger.warn do
            "Teacher CLUe skipped due to no information about book container #{book_container_uuid}"
          end
        end

        next
      end

      exercise_uuids = exercise_uuids_by_book_container_uuids[book_container_uuid]
      exercise_group_uuids = exercise_group_uuid_by_exercise_uuid.values_at(*exercise_uuids)
                                                                 .compact
                                                                 .uniq

      course_container_uuids.uniq.map do |course_container_uuid|
        student_uuids = student_uuids_by_course_container_uuids[course_container_uuid]
        if student_uuids.nil?
          Rails.logger.tagged('UpdateClues') do |logger|
            logger.warn do
              container_uuid = course_container_uuid

              "Teacher CLUe skipped due to no information about course container #{container_uuid}"
            end
          end

          next
        end

        student_response_maps = responses_map.values_at(*student_uuids).compact
        responses = student_response_maps.map do |student_response_map|
          student_response_map.values_at(*exercise_group_uuids)
        end.flatten.compact
        clue_data = calculate_clue_data(responses).merge(ecosystem_uuid: ecosystem_uuid)

        {
          course_container_uuid: course_container_uuid,
          book_container_uuid: book_container_uuid,
          clue_data: clue_data
        }
      end
    end.compact

    # Send CLUes to biglearn-api
    OpenStax::Biglearn::Api.update_student_clues(student_clues) if student_clues.any?
    OpenStax::Biglearn::Api.update_teacher_clues(teacher_clues) if teacher_clues.any?

    # Store the fact that the CLUes are up-to-date
    Response.import processable_new_responses, validate: false, on_duplicate_key_update: {
      conflict_target: [ :uuid ], columns: [ :used_in_clues_for_ecosystem_uuid ]
    }

    Rails.logger.tagged 'UpdateClues' do |logger|
      logger.info do
        time = Time.now - start_time

        "Updated: #{processable_new_responses.size} response(s) - Took: #{time} second(s)"
      end
    end
  end

  protected

  def calculate_clue_data(responses)
    if responses.size >= 3
      tot = responses.count
      suc = responses.count { |bool| !!bool }

      p_hat = (suc + 0.5*Z_ALPHA**2) / (tot + Z_ALPHA**2)

      var = responses.map { |bool| (p_hat - (bool ? 1 : 0))**2 }.reduce(&:+) / (tot - 1)

      interval = ( Z_ALPHA * Math.sqrt(p_hat*(1-p_hat)/(tot + Z_ALPHA**2)) +
                   0.1*Math.sqrt(var) + 0.05 )

      {
        minimum: [p_hat - interval, 0].max,
        most_likely: p_hat,
        maximum: [p_hat + interval, 1].min,
        is_real: true
      }
    else
      {
        minimum: 0,
        most_likely: 0.5,
        maximum: 1,
        is_real: false
      }
    end
  end
end
