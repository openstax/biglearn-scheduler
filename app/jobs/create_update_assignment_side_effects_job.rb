class CreateUpdateAssignmentSideEffectsJob < ApplicationJob
  include AssignmentExerciseRequests

  def perform_with_transaction(
    assignment_uuids:,
    assigned_exercise_uuids:,
    algorithm_exercise_calculation_uuids:
  )
    # Find relevant ExerciseCalculations
    # The ExerciseCalculation lock ensures we don't miss updates on
    # concurrent AlgorithmExerciseCalculation inserts
    assignment = Assignment.arel_table
    assigned_ex_ex_uuid = AssignedExercise.arel_table[:exercise_uuid]
    student_pe_ex_uuid = StudentPe.arel_table[:exercise_uuid]
    assignment_pe_ex_uuid = AssignmentPe.arel_table[:exercise_uuid]
    assignment_spe_ex_uuid = AssignmentSpe.arel_table[:exercise_uuid]
    ec = ExerciseCalculation.arel_table
    aec = AlgorithmExerciseCalculation.arel_table
    used_exercise_calculation_uuids = []
    a_uuids_by_alg_ex_calc_uuid = {}
    ExerciseCalculation
      .joins(
        <<~JOIN_SQL
          INNER JOIN "algorithm_exercise_calculations"
            ON "algorithm_exercise_calculations"."exercise_calculation_uuid" =
              "exercise_calculations"."uuid"
        JOIN_SQL
      )
      .joins(
        <<~JOIN_SQL
          INNER JOIN (
            (
              #{
                # This query is used to assign the most recent ExerciseCalculations
                # to a new or modified assignment
                ExerciseCalculation
                  .select(
                    <<~SELECT_SQL
                      DISTINCT ON (
                        "assignments"."uuid", "algorithm_exercise_calculations"."algorithm_name"
                      )
                      "exercise_calculations"."uuid",
                      "algorithm_exercise_calculations"."uuid"
                        AS "algorithm_exercise_calculation_uuid",
                      "assignments"."uuid" AS "assignment_uuid"
                    SELECT_SQL
                  )
                  .joins(:algorithm_exercise_calculations, :assignments)
                  .where(assignments: { uuid: assignment_uuids })
                  .merge(Assignment.need_pes_or_spes)
                  .order(assignment[:uuid], aec[:algorithm_name], superseded_at: :desc)
                  .to_sql
              }
            )
            UNION ALL
            #{
              # This query is used for PE deduplication
              ExerciseCalculation
                .select(
                  :uuid,
                  aec[:uuid].as('algorithm_exercise_calculation_uuid'),
                  assignment[:uuid].as('assignment_uuid')
                )
                .joins(
                  :algorithm_exercise_calculations,
                  assignments: :assignment_pes,
                  student: { assignments: :assigned_exercises }
                )
                .not_superseded
                .merge(Assignment.need_pes_or_spes)
                .where(assigned_ex_ex_uuid.eq(assignment_pe_ex_uuid))
                .where(assigned_exercises: { uuid: assigned_exercise_uuids })
                .to_sql
            }
            UNION ALL
            #{
              # This query is used for SPE deduplication
              ExerciseCalculation
                .select(
                  :uuid,
                  aec[:uuid].as('algorithm_exercise_calculation_uuid'),
                  assignment[:uuid].as('assignment_uuid')
                )
                .joins(
                  :algorithm_exercise_calculations,
                  assignments: :assignment_spes,
                  student: { assignments: :assigned_exercises }
                )
                .not_superseded
                .merge(Assignment.need_pes_or_spes)
                .where(assigned_ex_ex_uuid.eq(assignment_spe_ex_uuid))
                .where(assigned_exercises: { uuid: assigned_exercise_uuids })
                .to_sql
            }
            UNION ALL
            #{
              # This query is used for Student PE deduplication
              ExerciseCalculation
                .select(
                  :uuid,
                  aec[:uuid].as('algorithm_exercise_calculation_uuid'),
                  'NULL AS "assignment_uuid"'
                )
                .joins(
                  algorithm_exercise_calculations: :student_pes,
                  student: { assignments: :assigned_exercises }
                )
                .not_superseded
                .where(assigned_ex_ex_uuid.eq(student_pe_ex_uuid))
                .where(assigned_exercises: { uuid: assigned_exercise_uuids })
                .to_sql
            }
            UNION ALL
            #{
              # This query is used to mark ExerciseCalculations so they cannot be deleted
              ExerciseCalculation
                .select(
                  :uuid,
                  aec[:uuid].as('algorithm_exercise_calculation_uuid'),
                  'NULL as "assignment_uuid"'
                )
                .joins(:algorithm_exercise_calculations)
                .where(
                  algorithm_exercise_calculations: { uuid: algorithm_exercise_calculation_uuids }
                )
                .to_sql
            }
          ) AS "ec" ON "exercise_calculations".uuid = "ec"."uuid"
        JOIN_SQL
      )
      .ordered
      .lock('FOR NO KEY UPDATE OF "exercise_calculations", "algorithm_exercise_calculations"')
      .pluck(
        :uuid, :algorithm_exercise_calculation_uuid, :pending_assignment_uuids, :assignment_uuid
      )
      .each do |
        exercise_calculation_uuid,
        algorithm_exercise_calculation_uuid,
        pending_assignment_uuids,
        assignment_uuid
      |
      used_exercise_calculation_uuids << exercise_calculation_uuid \
        if algorithm_exercise_calculation_uuids.include? algorithm_exercise_calculation_uuid
      next if assignment_uuid.nil?

      a_uuids_by_alg_ex_calc_uuid[algorithm_exercise_calculation_uuid] ||= Set.new(
        pending_assignment_uuids
      )
      a_uuids_by_alg_ex_calc_uuid[algorithm_exercise_calculation_uuid] << assignment_uuid
    end

    algorithm_exercise_calculation_values = a_uuids_by_alg_ex_calc_uuid.map do |
      algorithm_exercise_calculation_uuid, assignment_uuids
    |
      [ algorithm_exercise_calculation_uuid, assignment_uuids.to_a ]
    end

    ExerciseCalculation.where(uuid: used_exercise_calculation_uuids).ordered_update_all(
      is_used_in_assignments: true
    ) unless used_exercise_calculation_uuids.empty?

    AlgorithmExerciseCalculation.update_all(
      <<~UPDATE_SQL
        "pending_assignment_uuids" = "values"."pending_assignment_uuids"
        FROM (#{ValuesTable.new(algorithm_exercise_calculation_values)}) AS "values"
          ("uuid", "pending_assignment_uuids")
        WHERE "algorithm_exercise_calculations"."uuid" = "values"."uuid"::uuid
      UPDATE_SQL
    ) unless algorithm_exercise_calculation_values.empty?

    # Anti-cheating: we don't allow StudentPes that have already been assigned elsewhere
    # Recalculate Student PEs that conflict with the AssignedExercises that were just created
    AlgorithmExerciseCalculation
      .joins(
        :student_pes, exercise_calculation: { student: { assignments: :assigned_exercises } }
      )
      .where('"assigned_exercises"."exercise_uuid" = "student_pes"."exercise_uuid"')
      .where(assigned_exercises: { uuid: assigned_exercise_uuids })
      .ordered_update_all(is_pending_for_student: true) \
        unless assigned_exercise_uuids.empty?

    # Get assignments that need PEs or SPEs and do not yet have an ExerciseCalculation
    default_assignments = Assignment.need_pes_or_spes.joins(
      :default_exercise_calculation
    ).where(uuid: assignment_uuids).where(
      AlgorithmExerciseCalculation.where(aec[:exercise_calculation_uuid].eq(ec[:uuid])).arel.exists
    ).where.not(
      ExerciseCalculation.where(
        ec[:student_uuid].eq(assignment[:student_uuid]),
        ec[:ecosystem_uuid].eq(assignment[:ecosystem_uuid])
      ).arel.exists
    ).preload(default_exercise_calculation: :algorithm_exercise_calculations).to_a

    exercise_uuids_map = get_exercise_uuids_map(
      default_assignments.map(&:assigned_book_container_uuids).uniq
    )

    excluded_uuids_by_student_uuid = get_excluded_exercises_by_student_uuid default_assignments

    # Create default assignment PE information
    default_pe_reqs = default_assignments.select(&:needs_pes?).flat_map do |assignment|
      exercise_calculation = assignment.default_exercise_calculation
      student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[assignment.student_uuid]

      exercise_calculation.algorithm_exercise_calculations.map do |algorithm_exercise_calculation|
        build_pe_request(
          algorithm_exercise_calculation: algorithm_exercise_calculation,
          assignment: assignment,
          exercise_uuids_map: exercise_uuids_map,
          excluded_exercise_uuids: student_excluded_exercise_uuids
        )
      end
    end

    # Send the default AssignmentPEs to the API server
    OpenStax::Biglearn::Api.update_assignment_pes(default_pe_reqs) if default_pe_reqs.any?

    # Create default assignment SPE information
    default_spe_reqs = default_assignments.select(&:needs_spes?).flat_map do |assignment|
      exercise_calculation = assignment.default_exercise_calculation
      student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[assignment.student_uuid]

      exercise_calculation.algorithm_exercise_calculations.flat_map do |aec|
        [ :student_driven, :instructor_driven ].map do |history_type|
          build_spe_request(
            algorithm_exercise_calculation: aec,
            assignment: assignment,
            assignment_sequence_number: 0,
            history_type: history_type,
            assignment_history: {
              0 => {
                assignment_uuid: assignment.uuid,
                book_container_uuids: assignment.assigned_book_container_uuids
              }
            },
            exercise_uuids_map: exercise_uuids_map,
            excluded_exercise_uuids: student_excluded_exercise_uuids
          )
        end
      end
    end

    # Send the default AssignmentSPEs to the API server
    OpenStax::Biglearn::Api.update_assignment_spes(default_spe_reqs) if default_spe_reqs.any?
  end
end
