require 'rails_helper'

RSpec.describe Services::FetchExerciseCalculations::Service, type: :service do
  let(:service)              { described_class.new }

  let(:given_algorithm_name) { 'tesr' }

  let(:action)               { service.process(algorithm_name: given_algorithm_name) }

  context "when non-existing ExerciseCalculation algorithm_names are given" do
    it "an empty array of exercise_calculations is returned" do
      expect(action.fetch(:exercise_calculations)).to be_empty
    end
  end

  context "when previously-existing ExerciseCalculation algorithm_names are given" do
    let(:calculation_uuid_1)   { SecureRandom.uuid }
    let(:calculation_uuid_2)   { SecureRandom.uuid }

    let(:num_exercise_uuids_1) { rand(10) + 1 }
    let(:num_student_uuids_1)  { rand(10) + 1 }
    let(:exercise_uuids_1)     { num_exercise_uuids_1.times.map { SecureRandom.uuid } }
    let(:student_uuids_1)      { num_student_uuids_1.times.map  { SecureRandom.uuid } }
    let(:ecosystem_uuid_1)     { SecureRandom.uuid }


    let(:num_exercise_uuids_2) { rand(10) + 1 }
    let(:num_student_uuids_2)  { rand(10) + 1 }
    let(:exercise_uuids_2)     { num_exercise_uuids_2.times.map { SecureRandom.uuid } }
    let(:student_uuids_2)      { num_student_uuids_2.times.map  { SecureRandom.uuid } }
    let(:ecosystem_uuid_2)     { SecureRandom.uuid }

    before do
      FactoryGirl.create :exercise_calculation, uuid: calculation_uuid_1,
                                                algorithm_name: given_algorithm_name,
                                                is_calculated: false,
                                                exercise_uuids: exercise_uuids_1,
                                                student_uuids: student_uuids_1,
                                                ecosystem_uuid: ecosystem_uuid_1

      FactoryGirl.create :exercise_calculation, uuid: calculation_uuid_2,
                                                algorithm_name: given_algorithm_name,
                                                is_calculated: false,
                                                exercise_uuids: exercise_uuids_2,
                                                student_uuids: student_uuids_2,
                                                ecosystem_uuid: ecosystem_uuid_2
    end

    context "when the ExerciseCalculations have already been calculated" do
      before do
        ExerciseCalculation.update_all(is_calculated: true)
      end

      it "an empty array of exercise_calculations is returned" do
        expect(action.fetch(:exercise_calculations)).to be_empty
      end
    end

    context "when the ExerciseCalculations have not yet been calculated" do
      it "the exercise_calculations are returned" do
        exercise_calculations_by_uuid = ExerciseCalculation.all.index_by(&:uuid)

        action.fetch(:exercise_calculations).each do |response|
          exercise_calculation = exercise_calculations_by_uuid.fetch(
            response.fetch(:calculation_uuid)
          )

          expect(response.fetch(:exercise_uuids)).to eq exercise_calculation.exercise_uuids
          expect(response.fetch(:student_uuids)).to eq exercise_calculation.student_uuids
          expect(response.fetch(:ecosystem_uuid)).to eq exercise_calculation.ecosystem_uuid
        end
      end
    end
  end
end
