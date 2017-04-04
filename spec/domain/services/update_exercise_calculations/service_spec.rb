require 'rails_helper'

RSpec.describe Services::UpdateExerciseCalculations::Service, type: :service do
  let(:service)                            { described_class.new }

  let(:given_algorithm_name)               { 'tesr' }

  let(:given_calculation_uuid_1)           { SecureRandom.uuid }
  let(:num_exercise_uuids_1)               { rand(10) }
  let(:given_exercise_uuids_1)             { num_exercise_uuids_1.times.map { SecureRandom.uuid } }

  let(:given_calculation_uuid_2)           { SecureRandom.uuid }
  let(:num_exercise_uuids_2)               { rand(10) }
  let(:given_exercise_uuids_2)             { num_exercise_uuids_2.times.map { SecureRandom.uuid } }

  let(:exercise_uuids_by_calculation_uuid) do
    {
      given_calculation_uuid_1 => given_exercise_uuids_1,
      given_calculation_uuid_2 => given_exercise_uuids_2
    }
  end

  let(:given_exercise_calculation_updates) do
    exercise_uuids_by_calculation_uuid.map do |calculation_uuid, exercise_uuids|
      {
        calculation_uuid: calculation_uuid,
        algorithm_name: given_algorithm_name,
        exercise_uuids: exercise_uuids
      }
    end
  end

  let(:action)                             do
    service.process(exercise_calculation_updates: given_exercise_calculation_updates)
  end

  context "when non-existing AlgorithmExerciseCalculation" +
          " calculation_uuid and algorithm_name are given" do
    it "creates new AlgorithmExerciseCalculation records for the given updates" do
      expect { action }.to change { AlgorithmExerciseCalculation.count }.by(2)

      new_algorithm_exercise_calculations = AlgorithmExerciseCalculation.where(
        exercise_calculation_uuid: exercise_uuids_by_calculation_uuid.keys
      )
      new_algorithm_exercise_calculations.each do |new_algorithm_exercise_calculation|
        expect(new_algorithm_exercise_calculation.algorithm_name).to eq given_algorithm_name

        calculation_uuid = new_algorithm_exercise_calculation.exercise_calculation_uuid
        exercise_uuids = exercise_uuids_by_calculation_uuid.fetch(calculation_uuid)
        expect(new_algorithm_exercise_calculation.exercise_uuids).to eq exercise_uuids
      end
    end
  end

  context "when previously-existing AlgorithmExerciseCalculation" +
          " calculation_uuid and algorithm_name are given" do
    before do
      FactoryGirl.create :algorithm_exercise_calculation,
                         exercise_calculation_uuid: given_calculation_uuid_1,
                         algorithm_name: given_algorithm_name

      FactoryGirl.create :algorithm_exercise_calculation,
                         exercise_calculation_uuid: given_calculation_uuid_2,
                         algorithm_name: given_algorithm_name
    end

    it "updates the AlgorithmExerciseCalculation records with the given updates" do
      expect { action }.not_to change { AlgorithmExerciseCalculation.count }

      new_algorithm_exercise_calculations = AlgorithmExerciseCalculation.where(
        exercise_calculation_uuid: exercise_uuids_by_calculation_uuid.keys
      )
      new_algorithm_exercise_calculations.each do |new_algorithm_exercise_calculation|
        expect(new_algorithm_exercise_calculation.algorithm_name).to eq given_algorithm_name

        calculation_uuid = new_algorithm_exercise_calculation.exercise_calculation_uuid
        exercise_uuids = exercise_uuids_by_calculation_uuid.fetch(calculation_uuid)
        expect(new_algorithm_exercise_calculation.exercise_uuids).to eq exercise_uuids
      end
    end
  end
end
