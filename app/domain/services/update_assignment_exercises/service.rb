class Services::UpdateAssignmentExercises::Service
  def process
    aa = Assignment.arel_table
    query = aa[:goal_num_tutor_assigned_spes].gt(aa[:num_assigned_spes])
              .and aa[:due_at].not_eq(nil)
              .or aa[:goal_num_tutor_assigned_pes].gt(aa[:num_assigned_pes])

    Assignment.with_instructor_based_sequence_numbers.where(query).find_in_batches do |assignments|
      assignment_by_assignment_uuid = assignments.index_by(&:uuid)

      # Build assignment histories so we can find SPE book_container_uuids
      history_queries = assignments.map do |assignment|
        # Don't consider assignments that don't need SPEs or have no due date
        spes_needed = assignment.goal_num_tutor_assigned_spes - assignment.num_assigned_spes
        k_ago_map = get_k_ago_map(spes_needed)
        due_at = assignment.due_at
        next if k_ago_map.nil? || due_at.nil?

        instructor_based_sequence_number = assignment.instructor_based_sequence_number
        sequence_number_queries = k_ago_map.map do |k_ago, num_exercises|
          aa[:instructor_based_sequence_number].eq(instructor_based_sequence_number - k_ago)
        end.reduce(:or)

        aa[:student_uuid].eq(assignment.student_uuid).and(
          aa[:assignment_type].eq(assignment.assignment_type).and(sequence_number_queries)
        )
      end.compact.reduce(:or)
      assignment_histories = Hash.new do |hash, key|
        hash[key] = Hash.new { |hash, key| hash[key] = {} }
      end
      Assignment.with_instructor_based_sequence_numbers
                .where(history_queries)
                .pluck(
                  :student_uuid,
                  :assignment_type,
                  :instructor_based_sequence_number,
                  :ecosystem_uuid,
                  :assigned_book_container_uuids
                ).each do |
                  student_uuid,
                  assignment_type,
                  instructor_based_sequence_number,
                  ecosystem_uuid,
                  assigned_book_container_uuids
                |
        assignment_histories[student_uuid][assignment_type][instructor_based_sequence_number] = \
          [ecosystem_uuid, assigned_book_container_uuids]
      end

      # Create a mapping of spaced practice book containers to each assignment's ecosystem
      bcm = BookContainerMapping.arel_table
      mapping_queries = assignments.map do |assignment|
        student_uuid = assignment.student_uuid
        assignment_type = assignment.assignment_type
        assignment_history = assignment_histories[student_uuid][assignment_type]

        spes_needed = assignment.goal_num_tutor_assigned_spes - assignment.num_assigned_spes
        k_ago_map = get_k_ago_map(spes_needed)

        instructor_based_sequence_number = assignment.instructor_based_sequence_number
        to_ecosystem_uuid = assignment.ecosystem_uuid

        spaced_assignments = k_ago_map.map do |k_ago, num_exercises|
          spaced_sequence_number = instructor_based_sequence_number - k_ago
          assignment_history[spaced_sequence_number]
        end.compact

        from_queries = spaced_assignments.map do |from_ecosystem_uuid, from_book_container_uuid|
          bcm[:from_ecosystem_uuid].eq(from_ecosystem_uuid).and(
            bcm[:from_book_container_uuid].eq(from_book_container_uuid)
          )
        end.reduce(:or)

        bcm[:to_ecosystem_uuid].eq(to_ecosystem_uuid).and(from_queries)
      end.reduce(:or)
      ecosystems_map = Hash.new { |hash, key| hash[key] = {} }
      BookContainerMapping
        .where(mapping_queries)
        .pluck(:to_ecosystem_uuid, :from_book_container_uuid, :to_book_container_uuid)
        .each do |to_ecosystem_uuid, from_book_container_uuid, to_book_container_uuid|
        ecosystems_map[to_ecosystem_uuid][from_book_container_uuid] = to_book_container_uuid
      end

      # Map all spaced book_container_uuids to the current ecosystem for each assignment
      spaced_practice_map = Hash.new { |hash, key| hash[key] = {} }
      assignments.each do |assignment|
        assignment_uuid = assignment.uuid
        student_uuid = assignment.student_uuid
        assignment_type = assignment.assignment_type
        assignment_history = assignment_histories[student_uuid][assignment_type]

        spes_needed = assignment.goal_num_tutor_assigned_spes - assignment.num_assigned_spes
        k_ago_map = get_k_ago_map(spes_needed)

        instructor_based_sequence_number = assignment.instructor_based_sequence_number
        to_ecosystem_uuid = assignment.ecosystem_uuid

        k_ago_map.each do |k_ago, num_exercises|
          spaced_sequence_number = instructor_based_sequence_number - k_ago
          ecosystem_uuid, spaced_book_container_uuids = assignment_history[spaced_sequence_number]

          mapped_book_containers = (spaced_book_container_uuids || []).map do |book_container_uuid|
            ecosystems_map[to_ecosystem_uuid][book_container_uuid]
          end

          spaced_practice_map[assignment_uuid][k_ago] = mapped_book_containers
        end
      end

      # Collect all relevant book container uuids for SPEs and PEs
      book_container_uuids = spaced_practice_map.values.flat_map(&:values) +
                             assignments.flat_map(&:assigned_book_container_uuids)

      # Get exercises for all relevant book_container_uuids
      @exercise_uuids_map = Hash.new do |hash, key|
        hash[key] = Hash.new { |hash, key| hash[key] = [] }
      end
      ExercisePool.where(book_container_uuid: book_container_uuids)
                  .pluck(:book_container_uuid, :assignment_type, :exercise_uuids)
                  .each do |book_container_uuid, assignment_type, exercise_uuids|
        @exercise_uuids_map[book_container_uuid][assignment_type].concat exercise_uuids
      end

      # Get exercise exclusions for each course
      course_uuids = assignment_by_assignment_uuid.values.map(&:course_uuid)
      exclusions = Course.where(uuid: course_uuids).pluck(
        :uuid,
        :global_excluded_exercise_uuids,
        :course_excluded_exercise_uuids,
        :global_excluded_exercise_group_uuids,
        :course_excluded_exercise_group_uuids
      )

      excluded_exercise_group_uuids = exclusions.flat_map(&:fourth) + exclusions.flat_map(&:fifth)
      excluded_exercise_uuids_by_group_uuid = Hash.new { |hash, key| hash[key] = [] }
      Exercise.where(group_uuid: excluded_exercise_group_uuids)
              .pluck(:group_uuid, :uuid)
              .each do |group_uuid, uuid|
        excluded_exercise_uuids_by_group_uuid[group_uuid] << uuid
      end

      excluded_uuids_set_by_course_uuid = Hash.new { |hash, key| hash[key] = Set.new }
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

        excluded_uuids_set_by_course_uuid[uuid].merge(
          global_excluded_exercise_uuids +
          course_excluded_exercise_uuids +
          converted_excluded_exercise_uuids
        )
      end

      # Get exercises that have already been assigned to each student
      student_uuids = assignment_by_assignment_uuid.values.map(&:student_uuid)
      @assigned_exercise_uuids_by_student_uuid = Hash.new { |hash, key| hash[key] = Set.new }
      Assignment.where(student_uuid: student_uuids)
                .pluck(:student_uuid, :assigned_exercise_uuids)
                .each do |student_uuid, assigned_exercise_uuids|
        @assigned_exercise_uuids_by_student_uuid[student_uuid].merge assigned_exercise_uuids
      end

      # Assign Spaced Practice and Personalized exercises
      assignment_spes = []
      assignment_pes = []
      spe_updates = []
      pe_updates = []
      assignments.group_by(&:course_uuid).each do |course_uuid, assignments|
        excluded_uuids_set = excluded_uuids_set_by_course_uuid[course_uuid]

        assignments.each do |assignment|
          assignment_uuid = assignment.uuid
          assignment_type = assignment.assignment_type

          spes_needed = assignment.goal_num_tutor_assigned_spes - assignment.num_assigned_spes
          k_ago_map = get_k_ago_map(spes_needed)

          assigned_book_container_uuids = assignment.assigned_book_container_uuids

          # Spaced Practice
          spaced_practice_exercise_uuids = k_ago_map.flat_map do |k_ago, num_exercises|
            k_ago_book_container_uuids = spaced_practice_map[assignment_uuid][k_ago]

            k_ago_exercise_uuids = get_exercise_uuids(
              book_container_uuids: k_ago_book_container_uuids,
              assignment_type: assignment_type,
              count: num_exercises
            )

            remaining_exercises = k_ago_exercise_uuids.size - num_exercises
            k_ago_exercise_uuids = k_ago_exercise_uuids + get_exercise_uuids(
              book_container_uuids: assigned_book_container_uuids,
              assignment_type: assignment_type,
              count: remaining_exercises
            ) if remaining_exercises > 0

            assignment_spes.concat k_ago_exercise_uuids.map do |spe_uuid|
              AssignmentSpe.new assignment_uuid: assignment_uuid, exercise_uuid: spe_uuid
            end

            k_ago_exercise_uuids
          end

          spe_updates << {
            assignment_uuid: assignment_uuid, exercise_uuids: spaced_practice_exercise_uuids
          }

          # Personalized
          personalized_exercise_uuids = get_exercise_uuids(
            book_container_uuids: assigned_book_container_uuids,
            assignment_type: assignment_type,
            count: assignment.goal_num_tutor_assigned_pes - assignment.num_assigned_pes
          )

          assignment_pes.concat personalized_exercise_uuids.map do |pe_uuid|
            AssignmentPe.new assignment_uuid: assignment_uuid, exercise_uuid: pe_uuid
          end

          pe_updates << {
            assignment_uuid: assignment_uuid, exercise_uuids: personalized_exercise_uuids
          }
        end
      end

      AssignmentSpe.import(
        assignment_spes, validate: false, on_duplicate_key_ignore: {
          conflict_target: [ :assignment_uuid, :exercise_uuid ]
        }
      )

      AssignmentPe.import(
        assignment_pes, validate: false, on_duplicate_key_ignore: {
          conflict_target: [ :assignment_uuid, :exercise_uuid ]
        }
      )

      OpenStax::Biglearn::Api.update_assignment_spes spe_updates
      OpenStax::Biglearn::Api.update_assignment_pes  pe_updates
    end
  end

  protected

  def get_k_ago_map(num_spes)
    # Entries in the list have the form:
    # [from-this-many-assignments-ago, pick-this-many-exercises]
    case num_spes
    when 0
      []
    when 1
      [ [2, 1] ]
    when 2
      [ [2, 1], [4, 1] ]
    when 3
      [ [2, 2], [4, 1] ]
    when 4
      [ [2, 2], [4, 2] ]
    else
      nil
    end
  end

  def get_exercise_uuids(assignment:, book_container_uuids:, count:)
    return [] if count == 0

    assignment_type = assignment.assignment_type

    # Get exercises in relevant book containers for relevant assignment type
    book_container_exercise_uuids = book_container_uuids.flat_map do |book_container_uuid|
      @exercise_uuids_map[book_container_uuid][assignment_type]
    end

    # Remove duplicates (same assignment) and exclusions
    candidate_exercise_uuids = book_container_exercise_uuids.reject do |uuid|
      assignment.assigned_exercise_uuids.include?(uuid) || excluded_uuids_set.include?(uuid)
    end

    # Partition remaining exercises into used and unused
    student_uuid = assignment.student_uuid
    assigned_exercise_uuids = @assigned_exercise_uuids_by_student_uuid[student_uuid]
    assigned_candidate_exercise_uuids, unassigned_candidate_exercise_uuids = \
      candidate_exercise_uuids.partition do |exercise_uuid|
      assigned_exercise_uuids.include?(exercise_uuid)
    end

    # Randomly pick exercises, preferring unassigned ones
    unassigned_count = unassigned_candidate_exercise_uuids.size
    chosen_exercises = if count <= unassigned_count
      unassigned_candidate_exercise_uuids.sample(count)
    else
      ( unassigned_candidate_exercise_uuids +
        assigned_candidate_exercise_uuids.sample(count - unassigned_count) ).shuffle
    end
  end
end
