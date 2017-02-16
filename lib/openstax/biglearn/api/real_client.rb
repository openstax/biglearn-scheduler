class OpenStax::Biglearn::Api::RealClient

  HEADER_OPTIONS = { headers: { 'Content-Type' => 'application/json' } }.freeze

  def initialize(biglearn_configuration)
    @server_url   = biglearn_configuration.server_url
    @client_id    = biglearn_configuration.client_id
    @secret       = biglearn_configuration.secret

    @oauth_client = OAuth2::Client.new @client_id, @secret, site: @server_url

    @oauth_token  = @oauth_client.client_credentials.get_token unless @client_id.nil?
  end

  #
  # API methods
  #

  def fetch_ecosystem_metadatas
    single_api_request url: :fetch_ecosystem_metadatas
  end

  def fetch_course_metadatas
    single_api_request url: :fetch_course_metadatas
  end

  def fetch_ecosystem_events(ecosystem_event_requests)
    bulk_api_request url: :fetch_ecosystem_events,
                     requests: ecosystem_event_requests,
                     requests_key: :ecosystem_event_requests,
                     responses_key: :ecosystem_event_responses
  end

  def fetch_course_events(course_event_requests)
    bulk_api_request url: :fetch_course_events,
                     requests: course_event_requests,
                     requests_key: :course_event_requests,
                     responses_key: :course_event_responses
  end

  def update_student_clues(student_clue_updates)
    bulk_api_request url: :update_student_clues,
                     requests: student_clue_updates,
                     requests_key: :student_clue_updates,
                     responses_key: :student_clue_update_responses
  end

  def update_teacher_clues(teacher_clue_updates)
    bulk_api_request url: :update_teacher_clues,
                     requests: teacher_clue_updates,
                     requests_key: :teacher_clue_updates,
                     responses_key: :teacher_clue_update_responses
  end

  def update_assignment_pes(pe_updates)
    bulk_api_request url: :update_assignment_pes,
                     requests: pe_updates,
                     requests_key: :pe_updates,
                     responses_key: :pe_update_responses
  end

  def update_assignment_spes(spe_updates)
    bulk_api_request url: :update_assignment_spes,
                     requests: spe_updates,
                     requests_key: :spe_updates,
                     responses_key: :spe_update_responses
  end

  def update_practice_worst_areas(practice_worst_areas_updates)
    bulk_api_request url: :update_practice_worst_areas_exercises,
                     requests: practice_worst_areas_updates,
                     requests_key: :practice_worst_areas_updates,
                     responses_key: :practice_worst_areas_update_responses
  end

  protected

  def absolutize_url(url)
    Addressable::URI.join @server_url, url.to_s
  end

  def request(method:, url:, body:)
    absolute_uri = absolutize_url(url)

    request_options = body.nil? ? HEADER_OPTIONS : HEADER_OPTIONS.merge(body: body.to_json)

    response = (@oauth_token || @oauth_client).request method, absolute_uri, request_options

    JSON.parse(response.body).deep_symbolize_keys
  end

  def single_api_request(method: :post, url:, request: nil)
    response_hash = request method: method, url: url, body: request

    block_given? ? yield(response_hash) : response_hash
  end

  def bulk_api_request(method: :post, url:, requests:,
                       requests_key:, responses_key:, max_requests: 1000)
    max_requests ||= requests.size

    requests.each_slice(max_requests) do |requests|
      body = { requests_key => requests }

      response_hash = request method: method, url: url, body: body

      responses_array = response_hash[responses_key]

      responses_array.map{ |response| block_given? ? yield(response) : response }
    end
  end

end
