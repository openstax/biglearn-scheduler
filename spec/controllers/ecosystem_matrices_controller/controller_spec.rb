require 'rails_helper'

RSpec.describe EcosystemMatricesController, type: :request do
  let(:given_algorithm_uuid) { SecureRandom.uuid }

  let(:calculation_uuid_1)   { SecureRandom.uuid }
  let(:calculation_uuid_2)   { SecureRandom.uuid }

  context '#fetch_ecosystem_matrix_updates' do
    let(:ecosystem_uuid_1)   { SecureRandom.uuid }
    let(:ecosystem_uuid_2)   { SecureRandom.uuid }

    let(:request_payload)    { { algorithm_uuid: given_algorithm_uuid } }

    let(:target_result)      do
      {
        ecosystem_matrix_updates: [
          {
            calculation_uuid: calculation_uuid_1,
            ecosystem_uuid: ecosystem_uuid_1
          },
          {
            calculation_uuid: calculation_uuid_2,
            ecosystem_uuid: ecosystem_uuid_2
          }
        ]
      }
    end
    let(:target_response)    { target_result }

    let(:service_double)     do
      instance_double(Services::FetchEcosystemMatrixUpdates::Service).tap do |dbl|
        allow(dbl).to receive(:process).with(request_payload).and_return(target_result)
      end
    end

    before(:each)            do
      allow(Services::FetchEcosystemMatrixUpdates::Service).to(
        receive(:new).and_return(service_double)
      )
    end

    context "when a valid request is made" do
      it "the request and response payloads are validated against their schemas" do
        expect_any_instance_of(described_class).to receive(:with_json_apis).and_call_original
        response_status, response_body = fetch_ecosystem_matrix_updates(
          request_payload: request_payload
        )
      end

      it "the response has status 200 (success)" do
        response_status, response_body = fetch_ecosystem_matrix_updates(
          request_payload: request_payload
        )
        expect(response_status).to eq(200)
      end

      it "the FetchEcosystemMatrixUpdates service is called with the correct course data" do
        response_status, response_body = fetch_ecosystem_matrix_updates(
          request_payload: request_payload
        )
        expect(service_double).to have_received(:process)
      end

      it "the response contains the target_response" do
        response_status, response_body = fetch_ecosystem_matrix_updates(
          request_payload: request_payload
        )
        expect(response_body).to eq(target_response.deep_stringify_keys)
      end
    end
  end

  context '#ecosystem_matrices_updated' do
    let(:request_payload)    do
      {
        ecosystem_matrices_updated: [
          {
            calculation_uuid: calculation_uuid_1,
            algorithm_uuid: given_algorithm_uuid
          },
          {
            calculation_uuid: calculation_uuid_2,
            algorithm_uuid: given_algorithm_uuid
          }
        ]
      }
    end

    let(:target_result)        do
      {
        ecosystem_matrix_updated_responses: [
          {
            calculation_uuid: calculation_uuid_1,
            update_status: 'success'
          },
          {
            calculation_uuid: calculation_uuid_2,
            update_status: 'success'
          }
        ]
      }
    end
    let(:target_response)    { target_result }

    let(:service_double)     do
      instance_double(Services::EcosystemMatricesUpdated::Service).tap do |dbl|
        allow(dbl).to receive(:process).with(request_payload).and_return(target_result)
      end
    end

    before(:each)            do
      allow(Services::EcosystemMatricesUpdated::Service).to receive(:new).and_return(service_double)
    end

    context "when a valid request is made" do
      it "the request and response payloads are validated against their schemas" do
        expect_any_instance_of(described_class).to receive(:with_json_apis).and_call_original
        response_status, response_body = ecosystem_matrices_updated(
          request_payload: request_payload
        )
      end

      it "the response has status 200 (success)" do
        response_status, response_body = ecosystem_matrices_updated(
          request_payload: request_payload
        )
        expect(response_status).to eq(200)
      end

      it "the EcosystemMatricesUpdated service is called with the correct course data" do
        response_status, response_body = ecosystem_matrices_updated(
          request_payload: request_payload
        )
        expect(service_double).to have_received(:process)
      end

      it "the response contains the target_response" do
        response_status, response_body = ecosystem_matrices_updated(
          request_payload: request_payload
        )
        expect(response_body).to eq(target_response.deep_stringify_keys)
      end
    end
  end

  protected

  def fetch_ecosystem_matrix_updates(request_payload:)
    make_post_request(
      route: '/fetch_ecosystem_matrix_updates',
      headers: { 'Content-Type' => 'application/json' },
      body:  request_payload.to_json
    )
    response_status  = response.status
    response_payload = JSON.parse(response.body)

    [response_status, response_payload]
  end

  def ecosystem_matrices_updated(request_payload:)
    make_post_request(
      route: '/ecosystem_matrices_updated',
      headers: { 'Content-Type' => 'application/json' },
      body:  request_payload.to_json
    )
    response_status  = response.status
    response_payload = JSON.parse(response.body)

    [response_status, response_payload]
  end
end
