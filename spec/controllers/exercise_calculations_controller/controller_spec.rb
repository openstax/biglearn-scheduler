require 'rails_helper'

RSpec.describe ExerciseCalculationsController, type: :request do
  let(:given_algorithm_name)  { 'tesr' }

  let(:calculation_uuid_1)    { SecureRandom.uuid }
  let(:calculation_uuid_2)    { SecureRandom.uuid }

  let(:num_exercise_uuids_1)  { rand(10) + 1 }
  let(:exercise_uuids_1)      { num_exercise_uuids_1.times.map { SecureRandom.uuid } }

  let(:num_exercise_uuids_2)  { rand(10) + 1 }
  let(:exercise_uuids_2)      { num_exercise_uuids_2.times.map { SecureRandom.uuid } }

  context '#fetch_exercise_calculations' do

    let(:num_student_uuids_1) { rand(10) + 1 }
    let(:student_uuids_1)     { num_student_uuids_1.times.map  { SecureRandom.uuid } }
    let(:ecosystem_uuid_1)    { SecureRandom.uuid }

    let(:num_student_uuids_2) { rand(10) + 1 }
    let(:student_uuids_2)     { num_student_uuids_2.times.map  { SecureRandom.uuid } }
    let(:ecosystem_uuid_2)    { SecureRandom.uuid }

    let(:request_payload)     { { algorithm_name: given_algorithm_name } }

    let(:target_result)       do
      {
        exercise_calculations: [
          {
            calculation_uuid: calculation_uuid_1,
            exercise_uuids: exercise_uuids_1,
            student_uuids: student_uuids_1,
            ecosystem_uuid: ecosystem_uuid_1
          },
          {
            calculation_uuid: calculation_uuid_2,
            exercise_uuids: exercise_uuids_2,
            student_uuids: student_uuids_2,
            ecosystem_uuid: ecosystem_uuid_2
          }
        ]
      }
    end
    let(:target_response)     { target_result }

    let(:service_double)      do
      instance_double(Services::FetchExerciseCalculations::Service).tap do |dbl|
        allow(dbl).to receive(:process).with(request_payload).and_return(target_result)
      end
    end

    before(:each)             do
      allow(Services::FetchExerciseCalculations::Service).to(
        receive(:new).and_return(service_double)
      )
    end

    context "when a valid request is made" do
      it "the request and response payloads are validated against their schemas" do
        expect_any_instance_of(described_class).to receive(:with_json_apis).and_call_original
        response_status, response_body = fetch_exercise_calculations(
          request_payload: request_payload
        )
      end

      it "the response has status 200 (success)" do
        response_status, response_body = fetch_exercise_calculations(
          request_payload: request_payload
        )
        expect(response_status).to eq(200)
      end

      it "the FetchExerciseCalculations service is called with the correct course data" do
        response_status, response_body = fetch_exercise_calculations(
          request_payload: request_payload
        )
        expect(service_double).to have_received(:process)
      end

      it "the response contains the target_response" do
        response_status, response_body = fetch_exercise_calculations(
          request_payload: request_payload
        )
        expect(response_body).to eq(target_response.deep_stringify_keys)
      end
    end
  end

  context '#update_exercise_calculations' do
    let(:request_payload)      do
      {
        exercise_calculation_updates: [
          {
            calculation_uuid: calculation_uuid_1,
            algorithm_name: given_algorithm_name,
            exercise_uuids: exercise_uuids_1
          },
          {
            calculation_uuid: calculation_uuid_2,
            algorithm_name: given_algorithm_name,
            exercise_uuids: exercise_uuids_2
          }
        ]
      }
    end

    let(:target_result)        do
      {
        exercise_calculation_update_responses: [
          {
            calculation_uuid: calculation_uuid_1,
            calculation_status: 'accepted'
          },
          {
            calculation_uuid: calculation_uuid_2,
            calculation_status: 'accepted'
          }
        ]
      }
    end
    let(:target_response)      { target_result }

    let(:service_double)       do
      instance_double(Services::UpdateExerciseCalculations::Service).tap do |dbl|
        allow(dbl).to receive(:process).with(request_payload).and_return(target_result)
      end
    end

    before(:each)              do
      allow(Services::UpdateExerciseCalculations::Service).to(
        receive(:new).and_return(service_double)
      )
    end

    context "when a valid request is made" do
      it "the request and response payloads are validated against their schemas" do
        expect_any_instance_of(described_class).to receive(:with_json_apis).and_call_original
        response_status, response_body = update_exercise_calculations(
          request_payload: request_payload
        )
      end

      it "the response has status 200 (success)" do
        response_status, response_body = update_exercise_calculations(
          request_payload: request_payload
        )
        expect(response_status).to eq(200)
      end

      it "the UpdateExerciseCalculations service is called with the correct course data" do
        response_status, response_body = update_exercise_calculations(
          request_payload: request_payload
        )
        expect(service_double).to have_received(:process)
      end

      it "the response contains the target_response" do
        response_status, response_body = update_exercise_calculations(
          request_payload: request_payload
        )
        expect(response_body).to eq(target_response.deep_stringify_keys)
      end
    end
  end

  protected

  def fetch_exercise_calculations(request_payload:)
    make_post_request(
      route: '/fetch_exercise_calculations',
      headers: { 'Content-Type' => 'application/json' },
      body:  request_payload.to_json
    )
    response_status  = response.status
    response_payload = JSON.parse(response.body)

    [response_status, response_payload]
  end

  def update_exercise_calculations(request_payload:)
    make_post_request(
      route: '/update_exercise_calculations',
      headers: { 'Content-Type' => 'application/json' },
      body:  request_payload.to_json
    )
    response_status  = response.status
    response_payload = JSON.parse(response.body)

    [response_status, response_payload]
  end
end
