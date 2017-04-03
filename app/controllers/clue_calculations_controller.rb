class ClueCalculationsController < JsonApiController

  def fetch_clue_calculations
    with_json_apis(input_schema:  _fetch_clue_calculations_request_payload_schema,
                   output_schema: _fetch_clue_calculations_response_payload_schema) do
      algorithm_uuid = json_parsed_request_payload.fetch(:algorithm_uuid)

      service = Services::FetchClueCalculations::Service.new
      result = service.process(algorithm_uuid: algorithm_uuid)

      response_payload = { clue_calculations: result.fetch(:clue_calculations) }

      render json: response_payload.to_json, status: 200
    end
  end

  def update_clue_calculations
    with_json_apis(input_schema:  _update_clue_calculations_request_payload_schema,
                   output_schema: _update_clue_calculations_response_payload_schema) do
      clue_calculation_updates = json_parsed_request_payload.fetch(:clue_calculation_updates)

      service = Services::UpdateClueCalculations::Service.new
      result = service.process(clue_calculation_updates: clue_calculation_updates)

      response_payload = {
        clue_calculation_update_responses: result.fetch(:clue_calculation_update_responses)
      }

      render json: response_payload.to_json, status: 200
    end
  end

  protected

  def _fetch_clue_calculations_request_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'algorithm_uuid': {'$ref': '#standard_definitions/uuid'}
      },
      'required': ['algorithm_uuid'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _fetch_clue_calculations_response_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'clue_calculations': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'calculation_uuid': {'$ref': '#standard_definitions/uuid'},
              'exercise_uuids': {
                'type': 'array',
                'items': {'$ref': '#standard_definitions/uuid'}
              },
              'student_uuids': {
                'type': 'array',
                'items': {'$ref': '#standard_definitions/uuid'}
              },
              'ecosystem_uuid': {'$ref': '#standard_definitions/uuid'}
            },
            'required': ['calculation_uuid', 'exercise_uuids', 'student_uuids', 'ecosystem_uuid'],
            'additionalProperties': false
          },
        },
      },
      'required': ['clue_calculations'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _update_clue_calculations_request_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'clue_calculation_updates': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'calculation_uuid': {'$ref': '#standard_definitions/uuid'},
              'algorithm_uuid':   {'$ref': '#standard_definitions/uuid'},
              'clue_data':        {'$ref': '#standard_definitions/clue_data'}
            },
            'required': ['calculation_uuid', 'algorithm_uuid', 'clue_data'],
            'additionalProperties': false
          }
        }
      },
      'required': ['clue_calculation_updates'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _update_clue_calculations_response_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'clue_calculation_update_responses': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'calculation_uuid': {'$ref': '#standard_definitions/uuid'},
              'calculation_status': {
                'emum': ['accepted']
              }
            },
            'required': ['calculation_uuid', 'calculation_status'],
            'additionalProperties': false
          }
        }
      },
      'required': ['clue_calculation_update_responses'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

end
