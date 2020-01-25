module Services::AssignmentExerciseRequests
  DEFAULT_NUM_PES_PER_BOOK_CONTAINER = 3
  DEFAULT_NUM_SPES_PER_K_AGO = 1

  K_AGOS_TO_LOAD = [ 1, 2, 3, 4, 5 ]
  NON_RANDOM_K_AGOS = [ 1, 3, 5 ]

  MIN_SEQUENCE_NUMBER_FOR_RANDOM_AGO = 5

  def get_excluded_exercises_by_student_uuid(assignments, current_time: Time.current)
    # Get exercise exclusions for each course
    course_uuids = assignments.map(&:course_uuid)
    course_exclusions_by_course_uuid = Course.where(uuid: course_uuids).pluck(
      :uuid,
      :global_excluded_exercise_uuids,
      :course_excluded_exercise_uuids,
      :global_excluded_exercise_group_uuids,
      :course_excluded_exercise_group_uuids
    ).index_by(&:first)

    # Get assignments that should have hidden feedback for each student
    student_uuids = assignments.map(&:student_uuid)
    no_feedback_yet_assignments = Assignment
                                    .where(student_uuid: student_uuids)
                                    .where(Assignment.arel_table[:feedback_at].gt(current_time))
                                    .pluck(:student_uuid, :assigned_exercise_uuids)

    # Convert excluded exercise uuids to group uuids
    assigned_exercise_uuids = no_feedback_yet_assignments.flat_map(&:second)
    assigned_exercise_group_uuid_by_uuid = Exercise.where(uuid: assigned_exercise_uuids)
                                                   .pluck(:uuid, :group_uuid)
                                                   .to_h

    # Convert exclusion group uuids to uuids
    excluded_exercise_group_uuids = course_exclusions_by_course_uuid.values.flat_map(&:fourth) +
                                    course_exclusions_by_course_uuid.values.flat_map(&:fifth) +
                                    assigned_exercise_group_uuid_by_uuid.values
    excluded_exercise_uuids_by_group_uuid = Hash.new { |hash, key| hash[key] = [] }
    Exercise.where(group_uuid: excluded_exercise_group_uuids)
            .pluck(:group_uuid, :uuid)
            .each do |group_uuid, uuid|
      excluded_exercise_uuids_by_group_uuid[group_uuid] << uuid
    end

    # Create a map of excluded exercise uuids for each student
    Hash.new { |hash, key| hash[key] = [] }.tap do |excluded_uuids_by_student_uuid|
      # Add the course exclusions to the map above
      assignments.group_by(&:course_uuid).each do |course_uuid, assignments|
        course_exclusions = course_exclusions_by_course_uuid[course_uuid]
        next if course_exclusions.nil?

        group_uuids = course_exclusions.fourth + course_exclusions.fifth
        converted_excluded_exercise_uuids =
          excluded_exercise_uuids_by_group_uuid.values_at(*group_uuids).flatten
        course_excluded_uuids = course_exclusions.second +
                                course_exclusions.third +
                                converted_excluded_exercise_uuids

        assignments.each do |assignment|
          excluded_uuids_by_student_uuid[assignment.student_uuid].concat course_excluded_uuids
        end
      end

      # Add the exclusions from no_feedback_yet_assignments to the map above
      no_feedback_yet_assignments.each do |student_uuid, assigned_exercise_uuids|
        excluded_group_uuids =
          assigned_exercise_group_uuid_by_uuid.values_at(*assigned_exercise_uuids)
        excluded_exercise_uuids =
          excluded_exercise_uuids_by_group_uuid.values_at(*excluded_group_uuids).flatten
        excluded_uuids_by_student_uuid[student_uuid].concat excluded_exercise_uuids
      end
    end
  end

  def get_k_ago_map(assignment, include_random_ago = false)
    # Entries in the list have the form:
    # [from-this-many-assignments-ago, pick-this-many-exercises]
    num_spes = assignment.goal_num_tutor_assigned_spes

    case num_spes
    when Integer
      # Tutor decides
      return [] if num_spes == 0

      # Subtract 1 for random-ago/personalized
      num_spes -= 1
      num_spes_per_k_ago, remainder = num_spes.divmod NON_RANDOM_K_AGOS.size

      [].tap do |k_ago_map|
        NON_RANDOM_K_AGOS.each_with_index do |k_ago, index|
          num_k_ago_spes = index < remainder ? num_spes_per_k_ago + 1 : num_spes_per_k_ago

          k_ago_map << [k_ago, num_k_ago_spes] if num_k_ago_spes > 0
        end

        k_ago_map << [(include_random_ago ? nil : 0), 1]
      end
    when NilClass
      # Biglearn decides
      NON_RANDOM_K_AGOS.map do |k_ago|
        [k_ago, DEFAULT_NUM_SPES_PER_K_AGO]
      end.compact.tap do |k_ago_map|
        k_ago_map << [(include_random_ago ? nil : 0), 1]
      end
    else
      raise ArgumentError, "Invalid assignment num_spes: #{num_spes.inspect}", caller
    end
  end

  def choose_exercise_uuids(
    assignment:,
    book_container_uuids:,
    prioritized_exercise_uuids:,
    excluded_exercise_uuids:,
    exercise_count:
  )
    book_container_uuids = [book_container_uuids].flatten

    # Get exercises in relevant book containers for the relevant assignment type
    book_container_exercise_uuids =
      @exercise_uuids_map[assignment.assignment_type].values_at(*book_container_uuids).flatten

    # Remove duplicates (same assignment), assigned exercises and exclusions
    allowed_exercise_uuids = book_container_exercise_uuids -
                             assignment.assigned_exercise_uuids -
                             excluded_exercise_uuids

    (prioritized_exercise_uuids & allowed_exercise_uuids).first(exercise_count)
  end

  def build_pe_request(algorithm_exercise_calculation:, assignment:, excluded_exercise_uuids:)
    assignment_type = assignment.assignment_type
    assignment_type_exercise_uuids_map = @exercise_uuids_map[assignment_type]
    assignment_excluded_uuids = excluded_exercise_uuids
    # Ignore book containers with no dynamic exercises
    book_container_uuids = assignment.assigned_book_container_uuids
                                     .uniq
                                     .reject do |book_container_uuid|
      ( assignment_type_exercise_uuids_map[book_container_uuid] - assignment_excluded_uuids ).empty?
    end.shuffle

    unless book_container_uuids.empty?
      num_pes_per_book_container, remainder = assignment.goal_num_tutor_assigned_pes.nil? ?
        [DEFAULT_NUM_PES_PER_BOOK_CONTAINER, 0] :
        assignment.goal_num_tutor_assigned_pes.divmod(book_container_uuids.size)
    end

    chosen_pe_uuids = book_container_uuids.flat_map do |book_container_uuid|
      book_container_num_pes = remainder > 0 ?
        num_pes_per_book_container + 1 : num_pes_per_book_container
      next [] if book_container_num_pes == 0

      choose_exercise_uuids(
        assignment: assignment,
        book_container_uuids: book_container_uuid,
        prioritized_exercise_uuids: algorithm_exercise_calculation.exercise_uuids,
        excluded_exercise_uuids: assignment_excluded_uuids,
        exercise_count: book_container_num_pes
      ).tap do |chosen_pe_uuids|
        num_chosen_pes = chosen_pe_uuids.size
        remainder += num_pes_per_book_container - num_chosen_pes
        assignment_excluded_uuids += chosen_pe_uuids
      end
    end

    algorithm_name = algorithm_exercise_calculation.algorithm_name

    {
      ecosystem_matrix_uuid: algorithm_exercise_calculation.ecosystem_matrix_uuid,
      calculation_uuid: algorithm_exercise_calculation.uuid,
      assignment_uuid: assignment.uuid,
      exercise_uuids: chosen_pe_uuids,
      algorithm_name: algorithm_name,
      spy_info: {
        assignment_type: assignment_type,
        exercise_algorithm_name: algorithm_name
      }
    }
  end

  def build_spe_request(algorithm_exercise_calculation:,
                        assignment:,
                        assignment_sequence_number:,
                        history_type:,
                        assignment_history:,
                        excluded_exercise_uuids:)
    include_random_ago = history_type == :student_driven &&
                         assignment_sequence_number >= MIN_SEQUENCE_NUMBER_FOR_RANDOM_AGO
    k_ago_map = get_k_ago_map(assignment, include_random_ago)

    assignment_excluded_uuids = excluded_exercise_uuids

    forbidden_random_k_agos = k_ago_map.map(&:first).compact
    allowed_random_k_agos = K_AGOS_TO_LOAD - forbidden_random_k_agos
    num_remaining_exercises = 0
    exercises_spy_info = {}
    chosen_spe_uuids = k_ago_map.flat_map do |k_ago, num_exercises|
      num_remaining_exercises += num_exercises

      k_agos = k_ago.nil? ? allowed_random_k_agos : [ k_ago ]
      spaced_assignments = assignment_history.values_at(*k_agos).flatten.compact
      book_container_uuids = spaced_assignments.flat_map { |hash| hash[:book_container_uuids] }
                                               .uniq
                                               .shuffle
      num_book_containers = book_container_uuids.size

      next [] if num_book_containers == 0

      # k-ago assignment exists
      num_spes_per_book_container, remainder = num_remaining_exercises.divmod(num_book_containers)

      book_container_uuids.flat_map do |book_container_uuid|
        book_container_num_spes = remainder > 0 ?
          num_spes_per_book_container + 1 : num_spes_per_book_container
        next [] if book_container_num_spes == 0

        choose_exercise_uuids(
          assignment: assignment,
          book_container_uuids: book_container_uuid,
          prioritized_exercise_uuids: algorithm_exercise_calculation.exercise_uuids,
          excluded_exercise_uuids: assignment_excluded_uuids,
          exercise_count: book_container_num_spes
        ).tap do |chosen_spe_uuids|
          num_chosen_spes = chosen_spe_uuids.size
          num_remaining_exercises -= num_chosen_spes
          remainder += num_spes_per_book_container - num_chosen_spes
          assignment_excluded_uuids += chosen_spe_uuids

          # SPE spy info
          chosen_k_ago = k_ago.nil? ? assignment_history.find do |k_ago, history_entry|
            history_entry[:book_container_uuids].include? book_container_uuid
          end.first : k_ago
          chosen_spe_uuids.each do |chosen_spe_uuid|
            exercises_spy_info[chosen_spe_uuid] = { k_ago: chosen_k_ago, is_random_ago: k_ago.nil? }
          end
        end
      end
    end

    # If not enough spaced practice exercises, fill up the rest with personalized ones
    chosen_pe_uuids = choose_exercise_uuids(
      assignment: assignment,
      book_container_uuids: assignment.assigned_book_container_uuids,
      prioritized_exercise_uuids: algorithm_exercise_calculation.exercise_uuids,
      excluded_exercise_uuids: assignment_excluded_uuids,
      exercise_count: num_remaining_exercises
    )

    # PE as SPE spy info
    chosen_pe_uuids.each do |chosen_pe_uuid|
      exercises_spy_info[chosen_pe_uuid] = { k_ago: 0, is_random_ago: false }
    end

    algorithm_name = algorithm_exercise_calculation.algorithm_name

    {
      ecosystem_matrix_uuid: algorithm_exercise_calculation.ecosystem_matrix_uuid,
      calculation_uuid: algorithm_exercise_calculation.uuid,
      assignment_uuid: assignment.uuid,
      exercise_uuids: chosen_spe_uuids + chosen_pe_uuids,
      algorithm_name: "#{history_type}_#{algorithm_name}",
      spy_info: {
        assignment_type: assignment.assignment_type,
        exercise_algorithm_name: algorithm_name,
        history_type: history_type,
        assignment_history: assignment_history,
        exercises: exercises_spy_info
      }
    }
  end
end
