class ClueCalculationsController < JsonApiController

  def fetch_clue_calculations
    respond_with_json_apis_and_service(
      input_schema: _fetch_clue_calculations_request_payload_schema,
      output_schema: _fetch_clue_calculations_response_payload_schema,
      service:Services::FetchClueCalculations::Service
    )
  end

  def update_clue_calculations
    respond_with_json_apis_and_service(
      input_schema: _update_clue_calculations_request_payload_schema,
      output_schema: _update_clue_calculations_response_payload_schema,
      service:Services::UpdateClueCalculations::Service
    )
  end

  protected

  def _fetch_clue_calculations_request_payload_schema
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
              'ecosystem_uuid': {'$ref': '#standard_definitions/uuid'},
              'student_uuids': {
                'type': 'array',
                'items': {'$ref': '#standard_definitions/uuid'}
              },
              'exercise_uuids': {
                'type': 'array',
                'items': {'$ref': '#standard_definitions/uuid'}
              },
              'responses': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'response_uuid': {'$ref': '#standard_definitions/uuid'},
                    'trial_uuid':    {'$ref': '#standard_definitions/uuid'},
                    'is_correct':    { 'type': 'boolean' }
                  },
                  'required': [ 'response_uuid', 'trial_uuid', 'is_correct' ],
                  'additionalProperties': false
                }
              }
            },
            'required': [
              'calculation_uuid',
              'ecosystem_uuid',
              'student_uuids',
              'exercise_uuids',
              'responses'
            ],
            'additionalProperties': false
          },
          'minItems': 0,
          'maxItems': 2000
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
              'algorithm_name':   { 'type': 'string' },
              'clue_data':        {'$ref': '#standard_definitions/clue_data'}
            },
            'required': ['calculation_uuid', 'algorithm_name', 'clue_data'],
            'additionalProperties': false
          },
          'minItems': 1,
          'maxItems': 2000
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
                'emum': ['calculation_unknown', 'calculation_accepted']
              }
            },
            'required': ['calculation_uuid', 'calculation_status'],
            'additionalProperties': false
          },
          'minItems': 1,
          'maxItems': 2000
        }
      },
      'required': ['clue_calculation_update_responses'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

end
