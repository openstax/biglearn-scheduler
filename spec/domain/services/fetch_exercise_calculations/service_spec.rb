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

    let!(:exercise_calculation_1) do
      FactoryGirl.create :exercise_calculation, uuid: calculation_uuid_1
    end
    let!(:exercise_calculation_2) do
      FactoryGirl.create :exercise_calculation, uuid: calculation_uuid_2
    end

    context "when the ExerciseCalculations have already been calculated" do
      before do
        FactoryGirl.create :algorithm_exercise_calculation,
                           exercise_calculation: exercise_calculation_1,
                           algorithm_name: given_algorithm_name
        exercise_calculation_1.algorithm_names << given_algorithm_name
        exercise_calculation_1.save!

        FactoryGirl.create :algorithm_exercise_calculation,
                           exercise_calculation: exercise_calculation_2,
                           algorithm_name: given_algorithm_name
        exercise_calculation_2.algorithm_names << given_algorithm_name
        exercise_calculation_2.save!
      end

      it "an empty array of exercise_calculations is returned" do
        expect(action.fetch(:exercise_calculations)).to be_empty
      end
    end

    context "when the ExerciseCalculations have not yet been calculated" do
      it "the exercise_calculations are returned" do
        exercise_calculations_by_uuid = [
          exercise_calculation_1, exercise_calculation_2
        ].index_by(&:uuid)

        action.fetch(:exercise_calculations).each do |response|
          exercise_calculation = exercise_calculations_by_uuid.fetch(
            response.fetch(:calculation_uuid)
          )

          expect(response.fetch(:ecosystem_uuid)).to eq exercise_calculation.ecosystem_uuid
          expect(response.fetch(:student_uuid)).to eq exercise_calculation.student_uuid
          expect(response.fetch(:exercise_uuids)).to(
            eq exercise_calculation.ecosystem.exercise_uuids
          )
        end
      end
    end
  end
end
