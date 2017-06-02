class Services::UploadStudentExercises::Service < Services::ApplicationService
  BATCH_SIZE = 10

  NUM_PES_PER_STUDENT = 5
  MAX_NUM_WORST_CLUES = NUM_PES_PER_STUDENT

  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadStudentExercises' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    st = Student.arel_table
    aec = AlgorithmExerciseCalculation.arel_table
    ec = ExerciseCalculation.arel_table
    cc = Course.arel_table
    spe = StudentPe.arel_table

    total_students = 0
    loop do
      num_students = Student.transaction do
        # Find students that need PEs
        students = Student
          .select([
            st[Arel.star],
            aec[:uuid].as('algorithm_exercise_calculation_uuid'),
            aec[:algorithm_name],
            aec[:exercise_uuids]
          ])
          .joins(:course, exercise_calculations: :algorithm_exercise_calculations)
          .where(ec[:ecosystem_uuid].eq(cc[:ecosystem_uuid]))
          .where(
            StudentPe.where(spe[:algorithm_exercise_calculation_uuid].eq aec[:uuid]).exists.not
          )
          .lock
          .take(BATCH_SIZE)
        student_uuids = students.map(&:uuid)

        # Get the worst clues for each student
        worst_clues_by_student_uuid_and_algorithm_name = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = [] }
        end
        AlgorithmStudentClueCalculation
          .with_student_clue_calculation_attributes_and_partitioned_rank(
            student_uuids: student_uuids
          )
          .where("partitioned_rank <= #{MAX_NUM_WORST_CLUES}")
          .order(:partitioned_rank)
          .each do |algorithm_student_clue_calculation|
          student_uuid = algorithm_student_clue_calculation.student_uuid
          algorithm_name = algorithm_student_clue_calculation.algorithm_name

          worst_clues_by_student_uuid_and_algorithm_name[student_uuid][algorithm_name] <<
            algorithm_student_clue_calculation
        end

        # Get all practice exercises in the relevant book containers
        relevant_book_container_uuids = worst_clues_by_student_uuid_and_algorithm_name
          .values.flat_map do |worst_clues_by_algorithm_name|
          worst_clues_by_algorithm_name.values.flat_map do |worst_clues|
            worst_clues.map(&:book_container_uuid)
          end
        end
        exercise_uuids_by_book_container_uuids = Hash.new { |hash, key| hash[key] = [] }
        ExercisePool.where(book_container_uuid: relevant_book_container_uuids).pluck(
          :book_container_uuid,
          :use_for_personalized_for_assignment_types,
          :exercise_uuids
        ).each do |book_container_uuid, assignment_types, exercise_uuids|
          next unless assignment_types.include? 'practice'

          exercise_uuids_by_book_container_uuids[book_container_uuid].concat exercise_uuids
        end

        # Get exercise exclusions for each course
        course_uuids = students.map(&:course_uuid)
        exclusions = Course.where(uuid: course_uuids).pluck(
          :uuid,
          :global_excluded_exercise_uuids,
          :course_excluded_exercise_uuids,
          :global_excluded_exercise_group_uuids,
          :course_excluded_exercise_group_uuids
        )

        excluded_exercise_group_uuids = exclusions.flat_map(&:fourth) +
                                        exclusions.flat_map(&:fifth)
        excluded_exercise_uuids_by_group_uuid = Hash.new { |hash, key| hash[key] = [] }
        Exercise.where(group_uuid: excluded_exercise_group_uuids)
                .pluck(:group_uuid, :uuid)
                .each do |group_uuid, uuid|
          excluded_exercise_uuids_by_group_uuid[group_uuid] << uuid
        end

        excluded_uuids_by_course_uuid = Hash.new { |hash, key| hash[key] = [] }
        exclusions.each do |
          uuid,
          global_excluded_exercise_uuids,
          course_excluded_exercise_uuids,
          global_excluded_exercise_group_uuids,
          course_excluded_exercise_group_uuids
        |
          group_uuids = global_excluded_exercise_group_uuids + course_excluded_exercise_group_uuids
          converted_excluded_exercise_uuids = group_uuids.flat_map do |group_uuid|
            excluded_exercise_uuids_by_group_uuid[group_uuid]
          end

          excluded_uuids_by_course_uuid[uuid].concat(
            global_excluded_exercise_uuids +
            course_excluded_exercise_uuids +
            converted_excluded_exercise_uuids
          )
        end

        # Get exercises that have already been assigned to each student
        student_assignments = Assignment
                                .where(student_uuid: student_uuids)
                                .pluck(:uuid, :student_uuid, :due_at, :assigned_exercise_uuids)
        student_assignment_uuids = student_assignments.map(&:first)
        assigned_and_not_due_exercise_uuids_by_student_uuid = Hash.new do |hash, key|
          hash[key] = []
        end
        student_assignments.select do |uuid, student_uuid, due_at, assigned_exercise_uuids|
          due_at.present? && due_at > start_time
        end.each do |uuid, student_uuid, due_at, assigned_exercise_uuids|
          assigned_and_not_due_exercise_uuids_by_student_uuid[student_uuid].concat(
            assigned_exercise_uuids
          )
        end

        # Convert relevant exercise uuids to group uuids
        relevant_exercise_uuids = ( exercise_uuids_by_book_container_uuids.values +
                                    student_assignments.map(&:fourth) ).flatten
        exercise_group_uuid_by_uuid = Exercise.where(uuid: relevant_exercise_uuids)
                                              .pluck(:uuid, :group_uuid)
                                              .to_h

        # Convert the map above to use exercise_group_uuids
        assigned_and_not_due_exercise_group_uuids_by_student_uuid = Hash.new do |hash, key|
          hash[key] = []
        end
        assigned_and_not_due_exercise_uuids_by_student_uuid
          .each do |student_uuid, assigned_and_not_due_exercise_uuids|
          assigned_and_not_due_exercise_group_uuids_by_student_uuid[student_uuid] =
            exercise_group_uuid_by_uuid.values_at(*assigned_and_not_due_exercise_uuids).uniq
        end

        student_pe_requests = []
        student_pes = students.flat_map do |student|
          student_uuid = student.uuid
          prioritized_exercise_uuids = student.exercise_uuids
          course_uuid = student.course_uuid
          course_excluded_uuids = excluded_uuids_by_course_uuid[course_uuid]

          # Collect info about exercises that have already been assigned to this student
          assigned_and_not_due_exercise_group_uuids =
            assigned_and_not_due_exercise_group_uuids_by_student_uuid[student_uuid]

          worst_clues_by_algorithm_name =
            worst_clues_by_student_uuid_and_algorithm_name[student_uuid]

          exercise_algorithm_name = student.algorithm_name
          clue_algorithm_name = StudentPe::EXERCISE_TO_CLUE_ALGORITHM_NAME[exercise_algorithm_name]

          worst_clues = worst_clues_by_algorithm_name[clue_algorithm_name] || []

          # Create a map of chosen exercises for each worst CLUe
          candidate_pe_uuids = worst_clues.map do |clue|
            # Get practice exercises in the CLUe's book container
            book_container_uuid = clue.book_container_uuid
            book_container_exercise_uuids = \
              exercise_uuids_by_book_container_uuids[book_container_uuid]

            # Remove exclusions and assigned and not yet due exercises
            allowed_pe_uuids = ( book_container_exercise_uuids -
                                 course_excluded_uuids ).reject do |allowed_exercise_uuid|
              exercise_group_uuid = exercise_group_uuid_by_uuid[allowed_exercise_uuid]
              assigned_and_not_due_exercise_group_uuids.include?(exercise_group_uuid)
            end

            (prioritized_exercise_uuids & allowed_pe_uuids).first(NUM_PES_PER_STUDENT)
          end

          num_worst_clues = worst_clues.size
          worst_clue_num_pes_map = get_worst_clue_num_pes_map(num_worst_clues)

          assigned_pe_uuids = []
          algorithm_exercise_calculation_uuid = student.algorithm_exercise_calculation_uuid
          # Assign the candidate exercises for each position in the worst_clue_pes_map
          # based on the priority of each CLUe
          new_student_pes = worst_clues.each_with_index.flat_map do |clue, index|
            clue_num_pes = worst_clue_num_pes_map[index] || 0

            next [] if clue_num_pes == 0 # No slot is available for this CLUe

            # Prioritize the candidate exercises for this slot
            prioritized_candidate_pe_uuids = (
              [ candidate_pe_uuids[index] ] +
              candidate_pe_uuids.first(index) +
              candidate_pe_uuids.last(num_worst_clues - index - 1)
            ).flatten.uniq - assigned_pe_uuids

            chosen_pe_uuids = prioritized_candidate_pe_uuids.first(clue_num_pes)
            assigned_pe_uuids += chosen_pe_uuids

            chosen_pe_uuids.map do |chosen_pe_uuid|
              StudentPe.new(
                uuid: SecureRandom.uuid,
                algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
                exercise_uuid: chosen_pe_uuid
              )
            end
          end.tap do |result|
            # If no PEs, record a StudentPe with nil exercise_uuid
            # to denote that we already processed this student
            result << StudentPe.new(
              uuid: SecureRandom.uuid,
              algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
              exercise_uuid: nil
            ) if result.empty?

            student_pe_requests << {
              student_uuid: student_uuid,
              exercise_uuids: result.map(&:exercise_uuid).compact,
              algorithm_name: exercise_algorithm_name
            }
          end
        end

        # Send the StudentPes to the api server and record them
        OpenStax::Biglearn::Api.update_practice_worst_areas(student_pe_requests) \
          if student_pe_requests.any?

        StudentPe.import student_pes, validate: false

        students.size
      end

      # If we got less students than the batch size, then this is the last batch
      total_students += num_students
      break if num_students < BATCH_SIZE
    end

    Rails.logger.tagged 'UploadStudentExercises' do |logger|
      logger.debug do
        "#{total_students} student(s) updated in #{Time.now - start_time} second(s)"
      end
    end
  end

  protected

  def get_worst_clue_num_pes_map(num_clues)
    case num_clues
    when 0
      []
    when 1
      [5]
    when 2
      [3, 2]
    when 3
      [2, 2, 1]
    when 4
      [2, 1, 1, 1]
    else
      # 5 is the current maximum
      [1, 1, 1, 1, 1]
    end
  end
end
