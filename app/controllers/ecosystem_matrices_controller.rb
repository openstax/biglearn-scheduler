class EcosystemMatricesController < JsonApiController

  def fetch_ecosystem_matrix_updates
    with_json_apis(input_schema:  _fetch_ecosystem_matrix_updates_request_payload_schema,
                   output_schema: _fetch_ecosystem_matrix_updates_response_payload_schema) do
      algorithm_uuid = json_parsed_request_payload.fetch(:algorithm_uuid)

      service = Services::FetchEcosystemMatrixUpdates::Service.new
      result = service.process(algorithm_uuid: algorithm_uuid)

      response_payload = { ecosystem_matrix_updates: result.fetch(:ecosystem_matrix_updates) }

      render json: response_payload.to_json, status: 200
    end
  end

  def ecosystem_matrices_updated
    with_json_apis(input_schema:  _ecosystem_matrices_updated_request_payload_schema,
                   output_schema: _ecosystem_matrices_updated_response_payload_schema) do
      ecosystem_matrices_updated = json_parsed_request_payload.fetch(:ecosystem_matrices_updated)

      service = Services::EcosystemMatricesUpdated::Service.new
      result = service.process(ecosystem_matrices_updated: ecosystem_matrices_updated)

      response_payload = {
        ecosystem_matrix_updated_responses: result.fetch(:ecosystem_matrix_updated_responses)
      }

      render json: response_payload.to_json, status: 200
    end
  end

  protected

  def _fetch_ecosystem_matrix_updates_request_payload_schema
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
              'algorithm_uuid':   {'$ref': '#standard_definitions/uuid'}
            },
            'required': ['calculation_uuid', 'algorithm_uuid'],
            'additionalProperties': false
          }
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
              'update_status': {
                'emum': ['success']
              }
            },
            'required': ['calculation_uuid', 'update_status'],
            'additionalProperties': false
          }
        }
      },
      'required': ['ecosystem_matrix_updated_responses'],
      'additionalProperties': false,
      'standard_definitions': _standard_definitions
    }
  end

end
