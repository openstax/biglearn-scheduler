class EcosystemMatricesController < JsonApiController

  def fetch_ecosystem_matrix_updates
    respond_with_json_apis_and_service(
      input_schema: _fetch_ecosystem_matrix_updates_request_payload_schema,
      output_schema: _fetch_ecosystem_matrix_updates_response_payload_schema,
      service: Services::FetchEcosystemMatrixUpdates::Service
    )
  end

  def ecosystem_matrices_updated
    respond_with_json_apis_and_service(
      input_schema: _ecosystem_matrices_updated_request_payload_schema,
      output_schema: _ecosystem_matrices_updated_response_payload_schema,
      service: Services::EcosystemMatricesUpdated::Service
    )
  end

  protected

  def _fetch_ecosystem_matrix_updates_request_payload_schema
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

  def _fetch_ecosystem_matrix_updates_response_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'ecosystem_matrix_updates': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'calculation_uuid': {'$ref': '#standard_definitions/uuid'},
              'ecosystem_uuid':   {'$ref': '#standard_definitions/uuid'}
            },
            'required': ['calculation_uuid', 'ecosystem_uuid'],
            'additionalProperties': false
          },
          'minItems': 0,
          'maxItems': 1000
        },
      },
      'required': ['ecosystem_matrix_updates'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _ecosystem_matrices_updated_request_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'ecosystem_matrices_updated': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'calculation_uuid': {'$ref': '#standard_definitions/uuid'},
              'algorithm_name':   { 'type': 'string' }
            },
            'required': ['calculation_uuid', 'algorithm_name'],
            'additionalProperties': false
          },
          'minItems': 1,
          'maxItems': 1000
        }
      },
      'required': ['ecosystem_matrices_updated'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

  def _ecosystem_matrices_updated_response_payload_schema
    {
      '$schema': JSON_SCHEMA,
      'type': 'object',
      'properties': {
        'ecosystem_matrix_updated_responses': {
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
          'maxItems': 1000
        }
      },
      'required': ['ecosystem_matrix_updated_responses'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

end
