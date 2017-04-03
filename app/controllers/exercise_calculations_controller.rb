class ExerciseCalculationsController < JsonApiController

  def fetch_exercise_calculations
    with_json_apis(input_schema:  _fetch_exercise_calculations_request_payload_schema,
                   output_schema: _fetch_exercise_calculations_response_payload_schema) do
      algorithm_uuid = json_parsed_request_payload.fetch(:algorithm_uuid)

      service = Services::FetchExerciseCalculations::Service.new
      result = service.process(algorithm_uuid: algorithm_uuid)

      response_payload = { exercise_calculations: result.fetch(:exercise_calculations) }

      render json: response_payload.to_json, status: 200
    end
  end

  def update_exercise_calculations
    with_json_apis(input_schema:  _update_exercise_calculations_request_payload_schema,
                   output_schema: _update_exercise_calculations_response_payload_schema) do
      exercise_calculation_updates =
        json_parsed_request_payload.fetch(:exercise_calculation_updates)

      service = Services::UpdateExerciseCalculations::Service.new
      result = service.process(exercise_calculation_updates: exercise_calculation_updates)

      response_payload = {
        exercise_calculation_update_responses: result.fetch(:exercise_calculation_update_responses)
      }

      render json: response_payload.to_json, status: 200
    end
  end

  protected

  def _fetch_exercise_calculations_request_payload_schema
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

  def _fetch_exercise_calculations_response_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'exercise_calculations': {
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
      'required': ['exercise_calculations'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _update_exercise_calculations_request_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'exercise_calculation_updates': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'calculation_uuid': {'$ref': '#standard_definitions/uuid'},
              'algorithm_uuid':   {'$ref': '#standard_definitions/uuid'},
              'exercise_uuids':   {
                type: 'array',
                items: {'$ref': '#standard_definitions/uuid'}
              }
            },
            'required': ['calculation_uuid', 'algorithm_uuid', 'exercise_uuids'],
            'additionalProperties': false
          }
        }
      },
      'required': ['exercise_calculation_updates'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _update_exercise_calculations_response_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'exercise_calculation_update_responses': {
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
      'required': ['exercise_calculation_update_responses'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

end
