class Services::UpdateAssignmentExercises::Service
  BATCH_SIZE = 1000

  def process
    aa = Assignment.arel_table
    query = aa[:goal_num_tutor_assigned_spes].gt(0).and(aa[:spes_are_assigned].eq(false))
              .or(aa[:goal_num_tutor_assigned_pes].gt(0).and(aa[:pes_are_assigned].eq(false)))

    Assignment.with_instructor_based_sequence_numbers
              .where(query)
              .find_in_batches(batch_size: BATCH_SIZE) do |assignments|
      assignment_by_assignment_uuid = assignments.index_by(&:uuid)

      # Build assignment histories so we can find SPE book_container_uuids
      history_queries = assignments.map do |assignment|
        # Don't consider assignments that need more SPEs than we can handle
        k_ago_map = get_k_ago_map(assignment.goal_num_tutor_assigned_spes)
        next if k_ago_map.blank?

        instructor_based_sequence_number = assignment.instructor_based_sequence_number
        sequence_number_queries = k_ago_map.map do |k_ago, num_exercises|
          aa[:instructor_based_sequence_number].eq(instructor_based_sequence_number - k_ago)
        end.reduce(:or)

        aa[:student_uuid].eq(assignment.student_uuid).and(
          aa[:assignment_type].eq(assignment.assignment_type).and(sequence_number_queries)
        ) unless sequence_number_queries.nil?
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
      end unless history_queries.nil?

      # Create a mapping of spaced practice book containers to each assignment's ecosystem
      bcm = BookContainerMapping.arel_table
      mapping_queries = assignments.map do |assignment|
        student_uuid = assignment.student_uuid
        assignment_type = assignment.assignment_type
        assignment_history = assignment_histories[student_uuid][assignment_type]

        k_ago_map = get_k_ago_map(assignment.goal_num_tutor_assigned_spes)

        instructor_based_sequence_number = assignment.instructor_based_sequence_number
        to_ecosystem_uuid = assignment.ecosystem_uuid

        spaced_assignments = k_ago_map.map do |k_ago, num_exercises|
          spaced_sequence_number = instructor_based_sequence_number - k_ago
          assignment_history[spaced_sequence_number]
        end.compact

        from_queries = spaced_assignments.map do |from_ecosystem_uuid, from_book_container_uuids|
          next if from_ecosystem_uuid == to_ecosystem_uuid

          bcm[:from_ecosystem_uuid].eq(from_ecosystem_uuid).and(
            bcm[:from_book_container_uuid].in(from_book_container_uuids)
          )
        end.compact.reduce(:or)

        bcm[:to_ecosystem_uuid].eq(to_ecosystem_uuid).and(from_queries) unless from_queries.nil?
      end.compact.reduce(:or)
      ecosystems_map = Hash.new { |hash, key| hash[key] = {} }
      BookContainerMapping.where(mapping_queries)
                          .pluck(
                            :to_ecosystem_uuid,
                            :from_book_container_uuid,
                            :to_book_container_uuid
                          ).each do |
                            to_ecosystem_uuid,
                            from_book_container_uuid,
                            to_book_container_uuid
                          |
        ecosystems_map[to_ecosystem_uuid][from_book_container_uuid] = to_book_container_uuid
      end unless mapping_queries.nil?

      # Map all spaced book_container_uuids to the current ecosystem for each assignment
      spaced_practice_map = Hash.new { |hash, key| hash[key] = {} }
      assignments.each do |assignment|
        assignment_uuid = assignment.uuid
        student_uuid = assignment.student_uuid
        assignment_type = assignment.assignment_type
        assignment_history = assignment_histories[student_uuid][assignment_type]

        k_ago_map = get_k_ago_map(assignment.goal_num_tutor_assigned_spes)

        instructor_based_sequence_number = assignment.instructor_based_sequence_number
        to_ecosystem_uuid = assignment.ecosystem_uuid

        k_ago_map.each do |k_ago, num_exercises|
          spaced_sequence_number = instructor_based_sequence_number - k_ago
          from_ecosystem_uuid, spaced_book_container_uuids = \
            assignment_history[spaced_sequence_number]
          spaced_book_container_uuids ||= []

          mapped_book_containers = if from_ecosystem_uuid == to_ecosystem_uuid
            spaced_book_container_uuids
          else
            spaced_book_container_uuids.map do |book_container_uuid|
              ecosystems_map[to_ecosystem_uuid][book_container_uuid]
            end
          end

          spaced_practice_map[assignment_uuid][k_ago] = mapped_book_containers
        end
      end

      # Collect all relevant book container uuids for SPEs and PEs
      book_container_uuids = spaced_practice_map.values.map(&:values).flatten +
                             assignments.flat_map(&:assigned_book_container_uuids)

      # Get exercises for all relevant book_container_uuids
      @exercise_uuids_map = Hash.new do |hash, key|
        hash[key] = Hash.new { |hash, key| hash[key] = [] }
      end
      ExercisePool.where(book_container_uuid: book_container_uuids).pluck(
        :book_container_uuid,
        :use_for_personalized_for_assignment_types,
        :exercise_uuids
      ).each do |book_container_uuid, assignment_types, exercise_uuids|
        assignment_types.each do |assignment_type|
          @exercise_uuids_map[book_container_uuid][assignment_type].concat exercise_uuids
        end
      end

      # Get any exercises that are already assigned as SPEs or PEs
      assignment_uuids = assignment_by_assignment_uuid.keys
      assigned_spes_by_assignment_uuid_and_k_ago = Hash.new do |hash, key|
        hash[key] = Hash.new { |hash, key| hash[key] = [] }
      end
      AssignmentSpe.where(assignment_uuid: assignment_uuids)
                   .pluck(:assignment_uuid, :exercise_uuid, :k_ago)
                   .each do |assignment_uuid, exercise_uuid, k_ago|
        assigned_spes_by_assignment_uuid_and_k_ago[assignment_uuid][k_ago] << exercise_uuid
      end
      assigned_pes_by_assignment_uuid = Hash.new { |hash, key| hash[key] = [] }
      AssignmentPe.where(assignment_uuid: assignment_uuids)
                  .pluck(:assignment_uuid, :exercise_uuid)
                  .each do |assignment_uuid, exercise_uuid|
        assigned_pes_by_assignment_uuid[assignment_uuid] << exercise_uuid
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
      assigned_exercise_uuids_by_student_uuid = Hash.new { |hash, key| hash[key] = [] }
      Assignment.where(student_uuid: student_uuids)
                .pluck(:student_uuid, :assigned_exercise_uuids)
                .each do |student_uuid, assigned_exercise_uuids|
        assigned_exercise_uuids_by_student_uuid[student_uuid].concat assigned_exercise_uuids
      end
      assigned_exercise_uuids = assigned_exercise_uuids_by_student_uuid.values.flatten

      # Convert relevant exercise uuids to group uuids
      relevant_exercise_uuids = @exercise_uuids_map.values.flat_map(&:values) +
                                assigned_exercise_uuids
      @exercise_group_uuid_by_uuid = Exercise.where(uuid: relevant_exercise_uuids)
                                             .pluck(:uuid, :group_uuid)
                                             .to_h

      # Convert map of already-assigned exercises to use group_uuid
      @assigned_exercise_group_uuids_by_student_uuid = {}
      assigned_exercise_uuids_by_student_uuid.each do |student_uuid, assigned_exercise_uuids|
        @assigned_exercise_group_uuids_by_student_uuid[student_uuid] = \
          @exercise_group_uuid_by_uuid.values_at(*assigned_exercise_uuids)
      end

      # Assign Spaced Practice and Personalized exercises
      assignment_spes = []
      assignment_pes = []
      spe_updates = []
      pe_updates = []
      assignments.group_by(&:course_uuid).each do |course_uuid, assignments|
        course_excluded_uuids_set = excluded_uuids_set_by_course_uuid[course_uuid]

        assignments.each do |assignment|
          assignment_uuid = assignment.uuid
          assignment_type = assignment.assignment_type
          student_uuid = assignment.student_uuid

          k_ago_map = get_k_ago_map(assignment.goal_num_tutor_assigned_spes)

          assigned_book_container_uuids = assignment.assigned_book_container_uuids

          assigned_spe_uuids_map = assigned_spes_by_assignment_uuid_and_k_ago[assignment_uuid]
          assigned_spe_uuids = assigned_spe_uuids_map.values.flatten
          assigned_pe_uuids = assigned_pes_by_assignment_uuid[assignment_uuid]

          assignment_excluded_uuids_set = course_excluded_uuids_set +
                                          assigned_spe_uuids +
                                          assigned_pe_uuids

          # Spaced Practice
          spaced_practice_exercise_uuids = k_ago_map.flat_map do |k_ago, num_exercises|
            assigned_k_ago_spe_uuids = assigned_spe_uuids_map[k_ago]
            spes_needed = num_exercises - assigned_k_ago_spe_uuids.size

            k_ago_book_container_uuids = spaced_practice_map[assignment_uuid][k_ago]

            new_k_ago_exercise_uuids = get_exercise_uuids(
              assignment: assignment,
              book_container_uuids: k_ago_book_container_uuids,
              excluded_uuids: assignment_excluded_uuids_set,
              count: spes_needed
            )
            assignment_excluded_uuids_set += new_k_ago_exercise_uuids

            # If not enough spaced practice exercises, fill up the rest with personalized ones
            personalized_exercises_needed = spes_needed - new_k_ago_exercise_uuids.size
            if personalized_exercises_needed > 0
              new_personalized_exercise_uuids = get_exercise_uuids(
                assignment: assignment,
                book_container_uuids: assigned_book_container_uuids,
                excluded_uuids: assignment_excluded_uuids_set,
                count: personalized_exercises_needed
              )
              assignment_excluded_uuids_set += new_personalized_exercise_uuids
            else
              new_personalized_exercise_uuids = []
            end

            new_exercise_uuids = new_k_ago_exercise_uuids + new_personalized_exercise_uuids

            new_assignment_spes = new_exercise_uuids.map do |spe_uuid|
              AssignmentSpe.new uuid: SecureRandom.uuid,
                                student_uuid: student_uuid,
                                assignment_uuid: assignment_uuid,
                                exercise_uuid: spe_uuid,
                                k_ago: k_ago
            end
            assignment_spes.concat new_assignment_spes

            assigned_k_ago_spe_uuids + new_exercise_uuids
          end

          assignment.spes_are_assigned = true

          spe_updates << {
            assignment_uuid: assignment_uuid,
            exercise_uuids: spaced_practice_exercise_uuids
          }

          # Personalized
          new_personalized_exercise_uuids = get_exercise_uuids(
            assignment: assignment,
            book_container_uuids: assigned_book_container_uuids,
            excluded_uuids: assignment_excluded_uuids_set,
            count: assignment.goal_num_tutor_assigned_pes - assigned_pe_uuids.size
          )

          new_assignment_pes = new_personalized_exercise_uuids.map do |pe_uuid|
            AssignmentPe.new uuid: SecureRandom.uuid,
                             assignment_uuid: assignment_uuid,
                             student_uuid: student_uuid,
                             exercise_uuid: pe_uuid
          end
          assignment_pes.concat new_assignment_pes

          personalized_exercise_uuids = assigned_pe_uuids + new_personalized_exercise_uuids

          assignment.pes_are_assigned = true

          pe_updates << {
            assignment_uuid: assignment_uuid,
            exercise_uuids: personalized_exercise_uuids
          }
        end
      end

      Assignment.import(
        assignments, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ],
          columns: [ :spes_are_assigned, :pes_are_assigned ]
        }
      )

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

  def get_exercise_uuids(assignment:, book_container_uuids:, excluded_uuids:, count:)
    return [] if count == 0

    assignment_uuid = assignment.uuid
    assignment_type = assignment.assignment_type

    # Get exercises in relevant book containers for relevant assignment type
    book_container_exercise_uuids = book_container_uuids.flat_map do |book_container_uuid|
      @exercise_uuids_map[book_container_uuid][assignment_type]
    end

    # Remove duplicates (same assignment - already assigned and already PEs/SPEs) and exclusions
    candidate_exercise_uuids = book_container_exercise_uuids.reject do |uuid|
      assignment.assigned_exercise_uuids.include?(uuid) || excluded_uuids.include?(uuid)
    end

    # Partition remaining exercises into used and unused
    student_uuid = assignment.student_uuid
    assigned_exercise_group_uuids = @assigned_exercise_group_uuids_by_student_uuid[student_uuid]
    assigned_candidate_exercise_uuids, unassigned_candidate_exercise_uuids = \
      candidate_exercise_uuids.partition do |exercise_uuid|
      group_uuid = @exercise_group_uuid_by_uuid[exercise_uuid]
      assigned_exercise_group_uuids.include?(group_uuid)
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
