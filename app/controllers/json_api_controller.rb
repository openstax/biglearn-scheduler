require 'json-schema'

class JsonApiController < ApplicationController

  # Skip verifying the CSRF token
  skip_before_action :verify_authenticity_token

  rescue_from Errors::AppRequestValidationError,  with: :_render_app_request_validation_error
  rescue_from ActiveRecord::RecordNotUnique,      with: :_render_app_record_not_unique
  rescue_from Errors::AppResponseValidationError, with: :_render_app_response_validation_error

  JSON_SCHEMA = 'http://json-schema.org/draft-04/schema#'

  def with_json_apis(input_schema: nil, output_schema: nil, &block)
    parsed_request = _validate_and_parse_request(input_schema)
    response_payload = block.call(parsed_request)
    render json: response_payload, status: 200
    _validate_response(output_schema)
  end

  def respond_with_json_apis_and_service(input_schema: nil, output_schema: nil, service:)
    with_json_apis(input_schema: input_schema, output_schema: output_schema) do |request_payload|
      input_schema.nil? ? service.process : service.process(request_payload)
    end
  end

  def _json_parsed_request_payload
    request.body.rewind
    JSON.parse(request.body.read).deep_symbolize_keys
  rescue StandardError => ex
    fail Errors::AppRequestValidationError.new('could not parse request json payload')
  end

  def _validate_and_parse_request(input_schema)
    return {} if input_schema.nil?

    fail Errors::AppRequestHeaderError.new('request must have Content-Type = application/json') \
      unless request.content_type == 'application/json'

    _json_parsed_request_payload.tap do |parsed_request|
      validation_errors = JSON::Validator.fully_validate(
        input_schema,
        parsed_request,
        insert_defaults: true,
        validate_schema: true
      )

      fail Errors::AppRequestSchemaError.new('request body failed validation', validation_errors) \
        if validation_errors.any?
    end
  end

  def _validate_response(output_schema)
    fail Errors::AppResponseStatusError.new("invalid response status: #{response.status}") \
      unless response.status == 200

    return {} if output_schema.nil?

    JSON.parse(response.body).tap do |parsed_response|
      validation_errors = JSON::Validator.fully_validate(
        output_schema,
        parsed_response,
        validate_schema: true
      )

      fail Errors::AppResponseSchemaError.new(
        'response body failed validation', validation_errors
      ) if validation_errors.any?
    end
  rescue StandardError => ex
    fail Errors::AppResponseValidationError.new('could not parse response json payload')
  end

  def _render_app_request_validation_error(exception)
    request.body.rewind
    request_body = request.body.read
    payload = {
      'errors': exception.errors,
      'request': request_body
    }
    render json: payload.to_json, status: 400
  end

  def _render_app_record_not_unique(exception)
    payload = {
      'exception': exception.class.name,
      'errors': exception.to_s
    }
    render json: payload.to_json, status: 422
  end

  def _render_app_response_validation_error(exception)
    payload = {
      'errors': exception.errors,
      'response': {
        'status':  response.status,
        'headers': response.headers,
        'body':    response.body
      }
    }
    response.status = 500
    response.body   = payload.to_json
  end

  module SchemaDefinitions

    def _standard_definitions
      {
        'uuid': {
          'type': 'string',
          'pattern': '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-' +
                     '4[a-fA-F0-9]{3}-[a-fA-F0-9]{4}-' +
                     '[a-fA-F0-9]{12}$',
        },
        'number_between_0_and_1': {
          'type': 'number',
          'minimum': 0,
          'maximum': 1,
        },
        'non_negative_integer': {
          'type': 'integer',
          'minumum': 0,
        },
        'datetime': {
          'type': 'string',
          'pattern': '^\d{4}-'                       + ## year
                     '(0[1-9]|1[0-2])-'              + ## month
                     '(0[1-9]|1[0-9]|2[0-9]|3[0-1])' + ## day of month
                     '(T|t)'                         + ## ISO8601 spacer
                     '(0[0-9]|1[0-9]|2[0-3]):'       + ## hour
                     '([0-5][0-9]):'                 + ## minute
                     '([0-5][0-9]|60)'               + ## second
                     '(\.\d{1,6})?'                  + ## fraction of second
                     '(Z|z)$'                          ## Zulu timezone
        },
        'clue_data': {
          'type': 'object',
          'properties': {
            'minimum': {'$ref': '#/standard_definitions/number_between_0_and_1'},
            'most_likely': {'$ref': '#/standard_definitions/number_between_0_and_1'},
            'maximum': {'$ref': '#/standard_definitions/number_between_0_and_1'},
            'is_real': {'type': 'boolean'},
            'ecosystem_uuid': {'$ref': '#/standard_definitions/uuid'}
          },
          'required': ['minimum', 'most_likely', 'maximum', 'is_real'],
          'additionalProperties': false
        }
      }
    end

    def _generic_error_schema
      {
        '$schema': JSON_SCHEMA,
        'type': 'object',
        'properties': {
          'errors': {
            'type': 'array',
            'items': {
              'type': 'string',
            },
            'minItems': 1,
          },
        },
        'required': ['errors'],
        'additionalProperties': false
      }
    end

  end

  # make methods available both on instance and class
  include SchemaDefinitions
  extend SchemaDefinitions

end
