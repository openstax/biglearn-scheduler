require_relative 'api/configuration'
require_relative 'api/fake_client'
require_relative 'api/real_client'
require_relative 'api/malformed_request'
require_relative 'api/result_type_error'

module OpenStax::Biglearn::Api
  mattr_accessor :client

  class << self

    def configuration
      @configuration ||= new_configuration
    end

    def configure
      yield configuration
    end

    def fetch_ecosystem_metadatas
      single_api_request method: :fetch_ecosystem_metadatas
    end

    def fetch_course_metadatas
      single_api_request method: :fetch_course_metadatas
    end

    def fetch_ecosystem_events(ecosystem_event_requests)
      bulk_api_request method: :fetch_ecosystem_events,
                       requests: ecosystem_event_requests,
                       keys: [ :event_types, :ecosystem, ],
                       optional_keys: [ :event_limit ]
    end

    def fetch_course_events(course_event_requests)
      bulk_api_request method: :fetch_course_events,
                       requests: course_event_requests,
                       keys: [ :event_types, :course ],
                       optional_keys: [ :event_limit ]
    end

    def update_student_clues(student_clue_updates)
      bulk_api_request method: :update_student_clues,
                       requests: student_clue_updates,
                       keys: [ :student_uuid, :book_container_uuid, :clue_data ]
    end

    def update_teacher_clues(teacher_clue_updates)
      bulk_api_request method: :update_teacher_clues,
                       requests: teacher_clue_updates,
                       keys: [ :course_container_uuid, :book_container_uuid, :clue_data ]
    end

    def update_assignment_pes(pe_updates)
      bulk_api_request method: :update_assignment_pes,
                       requests: pe_updates,
                       keys: [ :assignment_uuid, :exercise_uuids ]
    end

    def update_assignment_spes(spe_updates)
      bulk_api_request method: :update_assignment_spes,
                       requests: spe_updates,
                       keys: [ :assignment_uuid, :exercise_uuids ]
    end

    def update_practice_worst_areas(practice_worst_areas_updates)
      bulk_api_request method: :update_practice_worst_areas,
                       requests: practice_worst_areas_updates,
                       keys: [ :student_uuid, :exercise_uuids ]
    end

    def use_fake_client
      self.client = new_client FakeClient
    end

    def use_real_client
      self.client = new_client RealClient
    end

    protected

    def new_configuration
      OpenStax::Biglearn::Api::Configuration.new
    end

    def new_client(client_class)
      begin
        client_class.new(configuration)
      rescue StandardError => e
        raise "Biglearn client initialization error: #{e.message}"
      end
    end

    def verify_and_slice_request(method:, request:, keys:, optional_keys:)
      required_keys = [keys].flatten
      return if request.nil? && required_keys.empty?

      missing_keys = required_keys.reject{ |key| request.has_key? key }

      raise(
        OpenStax::Biglearn::Api::MalformedRequest,
        "Invalid request: #{method} request #{request.inspect
        } is missing these required key(s): #{missing_keys.inspect}"
      ) if missing_keys.any?

      request.slice(*required_keys)
    end

    def verify_result(result:, result_class: Hash)
      results_array = [result].flatten

      results_array.each do |result|
        raise(
          OpenStax::Biglearn::Api::ResultTypeError,
          "Invalid result: #{result} has type #{result.class.name
          } but expected type was #{result_class.name}"
        ) if result.class != result_class
      end

      result
    end

    def single_api_request(method:, request: nil, keys: [], optional_keys: [],
                           result_class: Hash, perform_later: false)
      verified_request = verify_and_slice_request method: method,
                                                  request: request,
                                                  keys: keys,
                                                  optional_keys: optional_keys

      if perform_later
        raise NotImplementedError
        #OpenStax::Biglearn::Api::Job.perform_later method.to_s, verified_request
      else
        response = verified_request.nil? ? client.send(method) :
                                           client.send(method, verified_request)

        verify_result(result: block_given? ? yield(request, response) : response,
                      result_class: result_class)
      end
    end

    def bulk_api_request(method:, requests:, keys:, optional_keys: [],
                         result_class: Hash, uuid_key: :request_uuid, perform_later: false)
      return {} if requests.blank?

      requests_map = {}
      [requests].flatten.map do |request|
        requests_map[SecureRandom.uuid] = verify_and_slice_request(
          method: method, request: request, keys: keys, optional_keys: optional_keys
        )
      end

      requests_array = requests_map.map{ |uuid, request| request.merge uuid_key => uuid }

      if perform_later
        raise NotImplementedError
        #OpenStax::Biglearn::Api::Job.perform_later method.to_s, requests_array
      else
        responses = {}
        client.send(method, requests_array).each do |response|
          request = requests_map[response[uuid_key]]

          responses[request] = verify_result(
            result: block_given? ? yield(request, response) : response, result_class: result_class
          )
        end

        # If given a Hash instead of an Array, return the response directly
        requests.is_a?(Hash) ? responses.values.first : responses
      end
    end

  end
end
