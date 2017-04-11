class Services::UpdateClueCalculations::Service
  def process(clue_calculation_updates:)
    relevant_calculation_uuids = clue_calculation_updates.map { |calc| calc[:calculation_uuid] }
    student_clue_calculations_by_uuid =
      StudentClueCalculation.where(uuid: relevant_calculation_uuids).index_by(&:uuid)
    teacher_clue_calculation_uuids =
      TeacherClueCalculation.where(uuid: relevant_calculation_uuids).pluck(:uuid)

    algorithm_student_clue_calculations = []
    algorithm_teacher_clue_calculations = []
    clue_calculation_update_responses = clue_calculation_updates.map do |clue_calculation_update|
      calculation_uuid = clue_calculation_update.fetch(:calculation_uuid)
      algorithm_name = clue_calculation_update.fetch(:algorithm_name)
      clue_data = clue_calculation_update.fetch(:clue_data)

      student_clue_calculation = student_clue_calculations_by_uuid[calculation_uuid]
      if student_clue_calculation.present?
        algorithm_student_clue_calculations << AlgorithmStudentClueCalculation.new(
          uuid: SecureRandom.uuid,
          student_clue_calculation_uuid: calculation_uuid,
          algorithm_name: algorithm_name,
          clue_data: clue_data,
          is_uploaded: false,
          student_uuid: student_clue_calculation.student_uuid,
          ecosystem_uuid: student_clue_calculation.ecosystem_uuid,
          book_container_uuid: student_clue_calculation.book_container_uuid,
          clue_value: clue_data.fetch('most_likely')
        )

        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
      elsif teacher_clue_calculation_uuids.include? calculation_uuid
        algorithm_teacher_clue_calculations << AlgorithmTeacherClueCalculation.new(
          uuid: SecureRandom.uuid,
          teacher_clue_calculation_uuid: calculation_uuid,
          algorithm_name: algorithm_name,
          clue_data: clue_data,
          is_uploaded: false
        )

        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
      else
        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_unknown' }
      end
    end

    AlgorithmStudentClueCalculation.import(
      algorithm_student_clue_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :student_clue_calculation_uuid, :algorithm_name ],
        columns: [ :clue_data, :clue_value ]
      }
    )

    AlgorithmTeacherClueCalculation.import(
      algorithm_teacher_clue_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :teacher_clue_calculation_uuid, :algorithm_name ],
        columns: [ :clue_data ]
      }
    )

    student_uuids_with_updated_clues = algorithm_student_clue_calculations.map(&:student_uuid)
    Student.where(uuid: student_uuids_with_updated_clues).update_all(pes_are_assigned: false)

    { clue_calculation_update_responses: clue_calculation_update_responses }
  end
end
