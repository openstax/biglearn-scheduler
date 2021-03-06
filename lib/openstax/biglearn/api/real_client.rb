class OpenStax::Biglearn::Api::RealClient

  HEADER_OPTIONS = { 'Content-Type' => 'application/json' }.freeze

  def initialize(biglearn_api_configuration)
    @server_url   = biglearn_api_configuration.server_url
    @token        = biglearn_api_configuration.token
    @client_id    = biglearn_api_configuration.client_id
    @secret       = biglearn_api_configuration.secret

    @oauth_client = OAuth2::Client.new @client_id, @secret, site: @server_url

    @oauth_token  = @oauth_client.client_credentials.get_token unless @client_id.nil?
  end

  #
  # API methods
  #

  def fetch_ecosystem_metadatas(request)
    request = request.slice(:max_num_metadatas).merge(
      metadata_sequence_number_offset: (Ecosystem.maximum(:metadata_sequence_number) || -1) + 1
    )

    single_api_request url: :fetch_ecosystem_metadatas, request: request
  end

  def fetch_course_metadatas(request)
    request = request.slice(:max_num_metadatas).merge(
      metadata_sequence_number_offset: (Course.maximum(:metadata_sequence_number) || -1) + 1
    )

    single_api_request url: :fetch_course_metadatas, request: request
  end

  def fetch_ecosystem_events(ecosystem_event_requests)
    requests = ecosystem_event_requests.map do |request|
      ecosystem = request.fetch(:ecosystem)

      request.slice(:request_uuid, :event_types).merge(
        ecosystem_uuid: ecosystem.uuid,
        sequence_number_offset: request.fetch(:restart, false) ? 0 : ecosystem.sequence_number
      )
    end

    bulk_api_request url: :fetch_ecosystem_events,
                     requests: requests,
                     requests_key: :ecosystem_event_requests,
                     other_params: { max_num_events: 1000 },
                     responses_key: :ecosystem_event_responses
  end

  def fetch_course_events(course_event_requests)
    requests = course_event_requests.map do |request|
      course = request.fetch(:course)

      request.slice(:request_uuid, :event_types).merge(
        course_uuid: course.uuid,
        sequence_number_offset: request.fetch(:restart, false) ? 0 : course.sequence_number
      )
    end

    bulk_api_request url: :fetch_course_events,
                     requests: requests,
                     requests_key: :course_event_requests,
                     other_params: { max_num_events: 1000 },
                     responses_key: :course_event_responses
  end

  def update_student_clues(student_clue_updates)
    requests = student_clue_updates.map do |request|
      request.slice(
        :request_uuid,
        :book_container_uuid,
        :student_uuid,
        :clue_data,
        :algorithm_name,
        :calculation_uuid
      )
    end

    bulk_api_request url: :update_student_clues,
                     requests: requests,
                     requests_key: :student_clue_updates,
                     responses_key: :student_clue_update_responses
  end

  def update_teacher_clues(teacher_clue_updates)
    requests = teacher_clue_updates.map do |request|
      request.slice(
        :request_uuid,
        :book_container_uuid,
        :course_container_uuid,
        :clue_data,
        :algorithm_name,
        :calculation_uuid
      )
    end

    bulk_api_request url: :update_teacher_clues,
                     requests: requests,
                     requests_key: :teacher_clue_updates,
                     responses_key: :teacher_clue_update_responses
  end

  def update_assignment_pes(pe_updates)
    requests = pe_updates.map do |request|
      request.slice(
        :request_uuid,
        :algorithm_name,
        :assignment_uuid,
        :exercise_uuids,
        :spy_info,
        :calculation_uuid,
        :ecosystem_matrix_uuid
      )
    end

    bulk_api_request url: :update_assignment_pes,
                     requests: requests,
                     requests_key: :pe_updates,
                     responses_key: :pe_update_responses
  end

  def update_assignment_spes(spe_updates)
    requests = spe_updates.map do |request|
      request.slice(
        :request_uuid,
        :algorithm_name,
        :assignment_uuid,
        :exercise_uuids,
        :spy_info,
        :calculation_uuid,
        :ecosystem_matrix_uuid
      )
    end

    bulk_api_request url: :update_assignment_spes,
                     requests: requests,
                     requests_key: :spe_updates,
                     responses_key: :spe_update_responses
  end

  def update_practice_worst_areas(practice_worst_areas_updates)
    requests = practice_worst_areas_updates.map do |request|
      request.slice(
        :request_uuid,
        :algorithm_name,
        :student_uuid,
        :exercise_uuids,
        :spy_info,
        :calculation_uuid,
        :ecosystem_matrix_uuid
      )
    end

    bulk_api_request url: :update_practice_worst_areas_exercises,
                     requests: requests,
                     requests_key: :practice_worst_areas_updates,
                     responses_key: :practice_worst_areas_update_responses
  end

  protected

  def absolutize_url(url)
    Addressable::URI.join @server_url, url.to_s
  end

  def api_request(method:, url:, body:)
    absolute_uri = absolutize_url(url)

    header_options = { headers: @token.nil? ? HEADER_OPTIONS : HEADER_OPTIONS.merge(
        'Biglearn-Api-Token' => @token
      )
    }
    request_options = body.nil? ? header_options : header_options.merge(body: body.to_json)

    response = (@oauth_token || @oauth_client).request method, absolute_uri, request_options

    JSON.parse(response.body).deep_symbolize_keys
  end

  def single_api_request(method: :post, url:, request: nil)
    response_hash = api_request method: method, url: url, body: request

    block_given? ? yield(response_hash) : response_hash
  end

  def bulk_api_request(method: :post, url:, requests:, requests_key:, max_requests: 1000,
                       other_params: {}, responses_key:)
    max_requests ||= requests.size

    requests.each_slice(max_requests).flat_map do |requests|
      body = other_params.merge(requests_key => requests)

      response_hash = api_request method: method, url: url, body: body

      responses_array = response_hash.fetch responses_key

      responses_array.map { |response| block_given? ? yield(response) : response }
    end
  end

end
