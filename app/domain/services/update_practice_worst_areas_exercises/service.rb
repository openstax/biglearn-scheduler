class Services::UpdatePracticeWorstAreasExercises::Service
  NUM_PRACTICE_EXERCISES = 5
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'UpdatePracticeWorstAreasExercises' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    total_students = 0
    loop do
      num_students = Student.transaction do
        # Process only students whose worst clue value or book container changed
        students = Student.where(pes_are_assigned: false).with_worst_clues.take(BATCH_SIZE)

        # Get PEs that are already assigned
        student_uuids = students.map(&:uuid)
        assigned_student_pe_uuids_by_student_uuids = Hash.new { |hash, key| hash[key] = [] }
        StudentPe.where(student_uuid: student_uuids)
                 .pluck(:student_uuid, :exercise_uuid)
                 .each do |student_uuid, exercise_uuid|
          assigned_student_pe_uuids_by_student_uuids[student_uuid] << exercise_uuid
        end

        # Get all practice exercises in the relevant book containers
        relevant_book_container_uuids = students.map(&:worst_clue_book_container_uuid)
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

        student_uuids = changed_container_student_uuids + unchanged_container_student_uuids
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

          assigned_student_pe_uuids = assigned_student_pe_uuids_by_student_uuids[student_uuid]
          pes_needed = NUM_PRACTICE_EXERCISES - assigned_student_pe_uuids.size
          worst_book_container_uuids = [ student.worst_clue_book_container_uuid ]

          # Get practice exercises in relevant book containers
          book_container_exercise_uuids = \
            worst_book_container_uuids.flat_map do |book_container_uuid|
            exercise_uuids_by_book_container_uuids[book_container_uuid]
          end

          # Remove course and global exclusions and exercises in assignments not yet due
          course_uuid = course_uuid_by_student_uuid[student_uuid]
          course_excluded_uuids = excluded_uuids_by_course_uuid[course_uuid]
          assigned_but_not_due_exercise_uuids = \
            assigned_but_not_due_exercise_uuids_by_student_uuids[student_uuid]
          candidate_exercise_uuids = book_container_exercise_uuids -
                                     course_excluded_uuids -
                                     assigned_but_not_due_exercise_uuids

          # Partition remaining exercises into used and unused by group uuid
          assigned_exercise_uuids = assigned_exercise_uuids_by_student_uuids[student_uuid]
          assigned_exercise_group_uuids = assigned_exercise_uuids.map do |assigned_exercise_uuid|
            exercise_group_uuid_by_uuid[assigned_exercise_uuid]
          end.compact
          assigned_candidate_exercise_uuids, unassigned_candidate_exercise_uuids = \
            candidate_exercise_uuids.partition do |exercise_uuid|
            group_uuid = exercise_group_uuid_by_uuid[exercise_uuid]
            assigned_exercise_group_uuids.include?(group_uuid)
          end

          # Randomly pick candidate exercises, preferring unassigned ones
          unassigned_count = unassigned_candidate_exercise_uuids.size
          new_student_pe_uuids = if pes_needed <= unassigned_count
            unassigned_candidate_exercise_uuids.sample(pes_needed)
          else
            ( unassigned_candidate_exercise_uuids +
              assigned_candidate_exercise_uuids.sample(pes_needed - unassigned_count) ).shuffle
          end

          new_student_pes = new_student_pe_uuids.map do |pe_uuid|
            StudentPe.new uuid: SecureRandom.uuid,
                          student_uuid: student.uuid,
                          exercise_uuid: pe_uuid
          end

          student.pes_are_assigned = true

          student_pes.concat new_student_pes

          student_pe_uuids = assigned_student_pe_uuids + new_student_pe_uuids

          practice_worst_areas_updates << {
            student_uuid: student.uuid,
            exercise_uuids: student_pe_uuids
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
end
