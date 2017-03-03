class Services::UpdatePracticeWorstAreasExercises::Service
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'UpdatePracticeWorstAreasExercises' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    total_students = 0
    loop do
      num_students = Student.transaction do
        # Process only students that are new or whose worst clue value or book container changed
        students = Student.where(pes_are_assigned: false)
                          .preload(:worst_student_clues)
                          .take(BATCH_SIZE)

        # Get PEs that are already assigned
        student_uuids = students.map(&:uuid)
        assigned_pe_uuids_map = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = [] }
        end
        StudentPe.where(student_uuid: student_uuids)
                 .pluck(:book_container_uuid, :student_uuid, :exercise_uuid)
                 .each do |book_container_uuid, student_uuid, exercise_uuid|
          assigned_pe_uuids_map[student_uuid][book_container_uuid] << exercise_uuid
        end

        # Get all practice exercises in the relevant book containers
        relevant_book_container_uuids = students.flat_map do |student|
          student.worst_student_clues.map(&:book_container_uuid)
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
        course_uuid_by_student_uuid = students.map { |student| [student.uuid, student.course_uuid] }
                                              .to_h
        course_uuids = course_uuid_by_student_uuid.values
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

        current_time = DateTime.now
        assigned_exercise_uuids_by_student_uuids = Hash.new { |hash, key| hash[key] = [] }
        assigned_but_not_due_exercise_uuids_by_student_uuids = Hash.new do |hash, key|
          hash[key] = []
        end
        Assignment.where(student_uuid: student_uuids)
                  .pluck(:student_uuid, :due_at, :assigned_exercise_uuids)
                  .each do |student_uuid, due_at, assigned_exercise_uuids|
          assigned_exercise_uuids_by_student_uuids[student_uuid].concat assigned_exercise_uuids

          assigned_but_not_due_exercise_uuids_by_student_uuids[student_uuid].concat(
            assigned_exercise_uuids
          ) if due_at.present? && due_at > current_time
        end
        assigned_exercise_uuids = assigned_exercise_uuids_by_student_uuids.values.flatten

        relevant_exercise_uuids = exercise_uuids_by_book_container_uuids.values.flatten +
                                  assigned_exercise_uuids
        exercise_group_uuid_by_uuid = Exercise.where(uuid: relevant_exercise_uuids)
                                              .pluck(:uuid, :group_uuid)
                                              .to_h

        student_pes = []
        practice_worst_areas_updates = []
        students.each do |student|
          student_uuid = student.uuid

          assigned_student_pe_uuids_map = assigned_pe_uuids_map[student_uuid]

          course_uuid = course_uuid_by_student_uuid[student_uuid]
          course_excluded_uuids = excluded_uuids_by_course_uuid[course_uuid]
          assigned_but_not_due_exercise_uuids = \
            assigned_but_not_due_exercise_uuids_by_student_uuids[student_uuid]

          student_excluded_uuids = course_excluded_uuids +
                                   assigned_student_pe_uuids_map.values.flatten +
                                   assigned_but_not_due_exercise_uuids

          worst_student_clues = student.worst_student_clues.to_a

          # Create a map of candidate exercises for each worst CLUe
          candidate_exercise_uuids = []
          worst_student_clues.each_with_index do |student_clue, index|
            book_container_uuid = student_clue.book_container_uuid

            # Get exercises already assigned for this CLUe
            assigned_clue_pe_uuids = assigned_student_pe_uuids_map[book_container_uuid]

            # Get practice exercises in the CLUe's book container
            book_container_exercise_uuids = \
              exercise_uuids_by_book_container_uuids[book_container_uuid]

            # Remove course, global exclusions, exercises in assignments not yet due
            # and exercises already assigned for this CLUe from the candidates
            candidate_exercise_uuids[index] = \
              book_container_exercise_uuids - student_excluded_uuids - assigned_clue_pe_uuids
          end

          num_worst_student_clues = worst_student_clues.size
          worst_clue_pes_map = get_worst_clue_pes_map(worst_student_clues.size)

          # Collect exercise group_uuids that have already been assigned to this student
          assigned_exercise_uuids = assigned_exercise_uuids_by_student_uuids[student_uuid]
          assigned_exercise_group_uuids = assigned_exercise_uuids.map do |assigned_exercise_uuid|
            exercise_group_uuid_by_uuid[assigned_exercise_uuid]
          end.compact

          # Assign the candidate exercises for each position in the worst_clue_pes_map
          # based on the priority of each CLUe
          student_pe_uuids = []
          worst_student_clues.each_with_index do |student_clue, index|
            book_container_uuid = student_clue.book_container_uuid
            assigned_clue_pe_uuids = assigned_student_pe_uuids_map[book_container_uuid]
            student_pe_uuids.concat assigned_clue_pe_uuids

            num_pes_needed = worst_clue_pes_map[index] - assigned_clue_pe_uuids.size

            next if num_pes_needed <= 0

            # Prioritize the CLUes for filling this slot
            prioritized_candidate_exercise_uuids = \
              [candidate_exercise_uuids[index]] +
              candidate_exercise_uuids.first(index) +
              candidate_exercise_uuids.last(num_worst_student_clues-index-1)

            new_clue_pe_uuids = []
            prioritized_candidate_exercise_uuids.each do |candidate_exercise_uuids|
              # Remove any candidate exercises that might have already been chosen
              available_candidate_exercise_uuids = candidate_exercise_uuids - student_pe_uuids

              # Partition remaining exercises into used and unused by group uuid
              assigned_candidate_exercise_uuids, unassigned_candidate_exercise_uuids = \
                available_candidate_exercise_uuids.partition do |exercise_uuid|
                group_uuid = exercise_group_uuid_by_uuid[exercise_uuid]
                assigned_exercise_group_uuids.include?(group_uuid)
              end

              # Randomly pick candidate exercises, preferring unassigned ones
              unassigned_count = unassigned_candidate_exercise_uuids.size

              new_clue_pe_uuids.concat(
                if num_pes_needed <= unassigned_count
                  unassigned_candidate_exercise_uuids.sample(num_pes_needed)
                else
                  unassigned_candidate_exercise_uuids +
                  assigned_candidate_exercise_uuids.sample(num_pes_needed - unassigned_count)
                end
              )

              num_pes_needed -= available_candidate_exercise_uuids.size

              break if num_pes_needed <= 0
            end

            new_clue_pes = new_clue_pe_uuids.map do |pe_uuid|
              StudentPe.new uuid: SecureRandom.uuid,
                            book_container_uuid: book_container_uuid,
                            student_uuid: student.uuid,
                            exercise_uuid: pe_uuid
            end
            student_pes.concat new_clue_pes

            student_pe_uuids.concat new_clue_pe_uuids
          end

          student.pes_are_assigned = true

          practice_worst_areas_updates << {
            student_uuid: student.uuid,
            exercise_uuids: student_pe_uuids.shuffle
          }
        end

        OpenStax::Biglearn::Api.update_practice_worst_areas practice_worst_areas_updates

        Student.import students, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ], columns: [ :pes_are_assigned ]
        }

        StudentPe.import student_pes, validate: false, on_duplicate_key_ignore: {
          conflict_target: [ :student_uuid, :exercise_uuid ]
        }

        students.size
      end

      # If we got less students than the batch size, then this is the last batch
      total_students += num_students
      break if num_students < BATCH_SIZE
    end

    Rails.logger.tagged 'UpdatePracticeWorstAreasExercises' do |logger|
      logger.info do
        time = Time.now - start_time

        "Updated: #{total_students} student(s) - Took: #{time} second(s)"
      end
    end
  end

  protected

  # TODO: Decide on the mapping...
  def get_worst_clue_pes_map(num_clues)
    case num_clues
    when 1
      [5]
    when 2
      [3, 2]
    when 3
      [2, 2, 1]
    when 4
      [2, 1, 1, 1]
    when 5
      # 5 is the max
      [1, 1, 1, 1, 1]
    else
      []
    end
  end
end
