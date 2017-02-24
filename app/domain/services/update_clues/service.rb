class Services::UpdateClues::Service
  Z_ALPHA = 0.68

  def process
    start_time = Time.now
    Rails.logger.tagged 'UpdateClues' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    # Any responses created/updated after the last CLUe update indicate the need for a new CLUe
    new_responses = Response.where(used_in_clues: false).to_a

    student_uuid_by_trial_uuid = new_responses.map do |response|
      [ response.uuid, response.student_uuid ]
    end.to_h

    # Build some hashes to minimize the number of queries
    student_uuids = student_uuid_by_trial_uuid.values
    course_container_uuids_by_student_uuids = Student.where(uuid: student_uuids)
                                                     .pluck(:uuid, :course_container_uuids)
                                                     .to_h

    course_container_uuids = course_container_uuids_by_student_uuids.values.flatten
    student_uuids_by_course_container_uuids = CourseContainer.where(uuid: course_container_uuids)
                                                             .pluck(:uuid, :student_uuids)
                                                             .to_h

    trial_uuids = student_uuid_by_trial_uuid.keys
    ecosystem_uuid_by_trial_uuid = Trial.where(uuid: trial_uuids)
                                        .pluck(:uuid, :ecosystem_uuid)
                                        .to_h

    ee = EcosystemExercise.arel_table
    ee_queries = new_responses.map do |response|
      trial_uuid = response.uuid
      ecosystem_uuid = ecosystem_uuid_by_trial_uuid[trial_uuid]
      if ecosystem_uuid.nil?
        Rails.logger.tagged('UpdateClues') do |logger|
          logger.warn { "New response skipped due to no information about trial #{trial_uuid}" }
        end

        next
      end

      exercise_uuid = response.exercise_uuid
      response.used_in_clues = true

      ee[:ecosystem_uuid].eq(ecosystem_uuid).and(ee[:exercise_uuid].eq(exercise_uuid))
    end.compact.reduce(:or)

    book_container_uuids_map = Hash.new { |hash, key| hash[key] = {} }
    EcosystemExercise.where(ee_queries)
                     .pluck(:exercise_uuid, :ecosystem_uuid, :book_container_uuids)
                     .each do |exercise_uuid, ecosystem_uuid, book_container_uuids|
      book_container_uuids_map[ecosystem_uuid][exercise_uuid] = book_container_uuids
    end

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

    exercise_uuids = exercise_uuids_by_book_container_uuids.values.flatten
    exercise_group_uuid_by_exercise_uuid = Exercise.where(uuid: exercise_uuids)
                                                   .pluck(:uuid, :group_uuid)
                                                   .to_h

    student_clues_to_update = Hash.new { |hash, key| hash[key] = [] }
    teacher_clues_to_update = Hash.new { |hash, key| hash[key] = [] }
    rsp = Response.arel_table
    response_queries = new_responses.map do |response|
      trial_uuid = response.uuid
      ecosystem_uuid = ecosystem_uuid_by_trial_uuid[trial_uuid]
      if ecosystem_uuid.nil?
        Rails.logger.tagged('UpdateClues') do |logger|
          logger.warn { "Old response skipped due to no information about trial #{trial_uuid}" }
        end

        next
      end

      student_uuid = response.student_uuid
      exercise_uuid = response.exercise_uuid

      # Find all book containers that contain the given exercise and all exercises in all of them
      book_container_uuids = book_container_uuids_map[ecosystem_uuid].fetch exercise_uuid, []
      exercise_uuids = \
        exercise_uuids_by_book_container_uuids.values_at(*book_container_uuids).flatten

      # Find all course containers that contain the given student
      course_container_uuids = course_container_uuids_by_student_uuids.fetch student_uuid, []

      book_container_uuids.each do |book_container_uuid|
        student_clues_to_update[book_container_uuid] << student_uuid

        teacher_clues_to_update[book_container_uuid].concat course_container_uuids
      end

      rsp[:student_uuid].in(student_uuids).and rsp[:exercise_uuid].in(exercise_uuids)
    end.compact.reduce(:or)

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
        clue_data = calculate_clue_data(responses: responses).merge(ecosystem_uuid: ecosystem_uuid)

        {
          student_uuid: student_uuid,
          book_container_uuid: book_container_uuid,
          clue_data: clue_data
        }
      end
    end.compact

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
        clue_data = calculate_clue_data(responses: responses).merge(ecosystem_uuid: ecosystem_uuid)

        {
          course_container_uuid: course_container_uuid,
          book_container_uuid: book_container_uuid,
          clue_data: clue_data
        }
      end
    end.compact

    OpenStax::Biglearn::Api.update_student_clues(student_clues) if student_clues.any?
    OpenStax::Biglearn::Api.update_teacher_clues(teacher_clues) if teacher_clues.any?

    Response.import new_responses, validate: false, on_duplicate_key_update: {
      conflict_target: [ :uuid ], columns: [ :used_in_clues ]
    }

    Rails.logger.tagged 'UpdateClues' do |logger|
      logger.info do
        time = Time.now - start_time

        "Updated: #{new_responses.size} response(s) - Took: #{time} second(s)"
      end
    end
  end

  protected

  def calculate_clue_data(responses:)
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
