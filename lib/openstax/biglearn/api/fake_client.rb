class OpenStax::Biglearn::Api::FakeClient

  def initialize(biglearn_configuration)
  end

  def fetch_ecosystem_metadatas(request)
    { ecosystem_responses: [] }
  end

  def fetch_course_metadatas(request)
    { course_responses: [] }
  end

  def fetch_ecosystem_events(ecosystem_event_requests)
    ecosystem_event_requests.map do |request|
      {
        request_uuid: request[:request_uuid],
        ecosystem_uuid: request[:ecosystem].uuid,
        events: [],
        is_gap: false,
        is_end: true
      }
    end
  end

  def fetch_course_events(course_event_requests)
    course_event_requests.map do |request|
      {
        request_uuid: request[:request_uuid],
        course_uuid: request[:course].uuid,
        events: [],
        is_gap: false,
        is_end: true
      }
    end
  end

  def update_student_clues(student_clue_updates)
    student_clue_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end
  end

  def update_teacher_clues(teacher_clue_updates)
    teacher_clue_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end
  end

  def update_assignment_pes(pe_updates)
    pe_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end
  end

  def update_assignment_spes(spe_updates)
    spe_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end
  end

  def update_practice_worst_areas(practice_worst_areas_updates)
    practice_worst_areas_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end
  end

end
