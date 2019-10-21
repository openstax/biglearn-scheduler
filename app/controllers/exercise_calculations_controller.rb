# NOTE: We could modify these APIs to have priority numbers for each exercise
#       instead of using the order in which they appear in the array
class ExerciseCalculationsController < JsonApiController

  def fetch_exercise_calculations
    scout_ignore! 0.99

    respond_with_json_apis_and_service(
      input_schema: _fetch_exercise_calculations_request_payload_schema,
      output_schema: _fetch_exercise_calculations_response_payload_schema,
      service: Services::FetchExerciseCalculations::Service
    )
  end

  def update_exercise_calculations
    scout_ignore! 0.90

    respond_with_json_apis_and_service(
      input_schema: _update_exercise_calculations_request_payload_schema,
      output_schema: _update_exercise_calculations_response_payload_schema,
      service: Services::UpdateExerciseCalculations::Service
    )
  end

  def fetch_algorithm_exercise_calculations
    respond_with_json_apis_and_service(
      input_schema: _fetch_algorithm_exercise_calculations_request_payload_schema,
      output_schema: _fetch_algorithm_exercise_calculations_response_payload_schema,
      service: Services::FetchAlgorithmExerciseCalculations::Service
    )
  end

  protected

  def _fetch_exercise_calculations_request_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'algorithm_name': { 'type': 'string' }
      },
      'required': ['algorithm_name'],
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
              'ecosystem_uuid': {'$ref': '#standard_definitions/uuid'},
              'student_uuid': {'$ref': '#standard_definitions/uuid'},
              'exercise_uuids': {
                'type': 'array',
                'items': {'$ref': '#standard_definitions/uuid'}
              }
            },
            'required': ['calculation_uuid', 'ecosystem_uuid', 'student_uuid', 'exercise_uuids'],
            'additionalProperties': false
          },
          'minItems': 0,
          'maxItems': 10
        }
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
              'calculation_uuid':      {'$ref': '#standard_definitions/uuid'},
              'algorithm_name':        { 'type': 'string' },
              'ecosystem_matrix_uuid': {'$ref': '#standard_definitions/uuid'},
              'exercise_uuids':        {
                'type': 'array',
                'items': {'$ref': '#standard_definitions/uuid'}
              }
            },
            'required': [
              'calculation_uuid',
              'algorithm_name',
              'ecosystem_matrix_uuid',
              'exercise_uuids'
            ],
            'additionalProperties': false
          },
          'minItems': 1,
          'maxItems': 10
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
                'emum': ['calculation_unknown', 'calculation_accepted']
              }
            },
            'required': ['calculation_uuid', 'calculation_status'],
            'additionalProperties': false
          },
          'minItems': 1,
          'maxItems': 10
        }
      },
      'required': ['exercise_calculation_update_responses'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _fetch_algorithm_exercise_calculations_request_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'algorithm_exercise_calculations': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'request_uuid':     {'$ref': '#standard_definitions/uuid'},
              'student_uuid':     {'$ref': '#standard_definitions/uuid'},
              'calculation_uuid': {'$ref': '#standard_definitions/uuid'}
            },
            'anyOf': [
              {'required': ['request_uuid', 'student_uuid']},
              {'required': ['request_uuid', 'calculation_uuid']}
            ],
            'additionalProperties': false
          },
          'minItems': 1,
          'maxItems': 10
        }
      },
      'required': ['algorithm_exercise_calculations'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _fetch_algorithm_exercise_calculations_response_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'algorithm_exercise_calculations': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'request_uuid':          {'$ref': '#standard_definitions/uuid'},
              'calculation_uuid':      {'$ref': '#standard_definitions/uuid'},
              'ecosystem_matrix_uuid': {'$ref': '#standard_definitions/uuid'},
              'algorithm_name':        { 'type': 'string' },
              'exercise_uuids':        {
                'type': 'array',
                'items': {'$ref': '#standard_definitions/uuid'}
              }
            },
            'required': [
              'calculation_uuid',
              'ecosystem_matrix_uuid',
              'algorithm_name',
              'exercise_uuids'
            ],
            'additionalProperties': false
          },
          'minItems': 1,
          'maxItems': 10
        }
      },
      'required': ['algorithm_exercise_calculations'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end
end
