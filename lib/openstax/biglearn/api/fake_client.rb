class OpenStax::Biglearn::Api::FakeClient

  def initialize(biglearn_configuration)
  end

  def fetch_ecosystem_metadatas
    { ecosystem_responses: [] }
  end

  def fetch_course_metadatas
    { course_responses: [] }
  end

  def fetch_ecosystem_events(ecosystem_event_requests)
    ecosystem_event_responses = ecosystem_event_requests.map do |request|
      {
        request_uuid: request[:request_uuid],
        ecosystem_uuid: request[:ecosystem_uuid],
        events: []
      }
    end

    { ecosystem_event_responses: ecosystem_event_responses }
  end

  def fetch_course_events(course_event_requests)
    course_event_responses = course_event_requests.map do |request|
      {
        request_uuid: request[:request_uuid],
        course_uuid: request[:course_uuid],
        events: []
      }
    end

    { course_event_responses: course_event_responses }
  end

  def update_student_clues(student_clue_updates)
    student_clue_responses = student_clue_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end

    { student_clue_responses: student_clue_responses }
  end

  def update_teacher_clues(teacher_clue_updates)
    teacher_clue_responses = teacher_clue_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end

    { teacher_clue_responses: teacher_clue_responses }
  end

  def update_assignment_pes(pe_updates)
    pe_update_responses = pe_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end

    { pe_update_responses: pe_update_responses }
  end

  def update_assignment_spes(spe_updates)
    spe_update_responses = spe_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end

    { spe_update_responses: spe_update_responses }
  end

  def update_practice_worst_areas(practice_worst_areas_updates)
    practice_worst_areas_update_responses = practice_worst_areas_updates.map do |request|
      { request_uuid: request[:request_uuid], update_status: 'accepted' }
    end

    { practice_worst_areas_update_responses: practice_worst_areas_update_responses }
  end

end
