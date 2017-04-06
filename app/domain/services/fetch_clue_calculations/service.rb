class Services::FetchClueCalculations::Service
  def process(algorithm_name:)
    scc = StudentClueCalculation.arel_table
    ascc = AlgorithmStudentClueCalculation.arel_table
    scc_query = scc[:uuid].eq(ascc[:student_clue_calculation_uuid]).and(
      ascc[:algorithm_name].eq(algorithm_name)
    )
    scc_join = "LEFT OUTER JOIN algorithm_student_clue_calculations ON #{scc_query.to_sql}"
    student_clue_calculations = StudentClueCalculation
                                  .joins(scc_join)
                                  .where(algorithm_student_clue_calculations: {id: nil})
                                  .limit(1000)

    tcc = TeacherClueCalculation.arel_table
    atcc = AlgorithmTeacherClueCalculation.arel_table
    tcc_query = tcc[:uuid].eq(atcc[:teacher_clue_calculation_uuid]).and(
      atcc[:algorithm_name].eq(algorithm_name)
    )
    tcc_join = "LEFT OUTER JOIN algorithm_teacher_clue_calculations ON #{tcc_query.to_sql}"
    teacher_clue_calculations = TeacherClueCalculation
                                  .joins(tcc_join)
                                  .where(algorithm_teacher_clue_calculations: {id: nil})
                                  .limit(1000)

    clue_calculations = student_clue_calculations + teacher_clue_calculations
    clue_calculation_responses = clue_calculations.map do |clue_calculation|
      {
        calculation_uuid: clue_calculation.uuid,
        ecosystem_uuid: clue_calculation.ecosystem_uuid,
        student_uuids: clue_calculation.student_uuids,
        exercise_uuids: clue_calculation.exercise_uuids,
        response_uuids: clue_calculation.response_uuids
      }
    end

    { clue_calculations: clue_calculation_responses }
  end
end
